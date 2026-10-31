<?php

namespace App\Services\Gamification;

use App\Models\User;
use App\Models\UserMission;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

/**
 * Server-side XP, level, streak and mission engine.
 *
 * Everything the Tauti mascot card shows on Beranda and Profil is computed
 * here and exposed through `GET /api/v1/gamification/summary`; the Flutter app
 * never calculates XP on its own (PRD FR-GAME-01 AC-1).
 */
class XpLevelService
{
    /**
     * Award XP for a brand-new saved link and advance the streak.
     *
     * Duplicates must NOT reach this method: `QuickSaveLinkAction` keeps the
     * "one save = one XP grant" rule so XP cannot be farmed (AC-3).
     *
     * @return array{xp: int, level: int, leveled_up: bool, streak_days: int, xp_to_next_level: int}
     */
    public function awardSave(User $user): array
    {
        $result = $this->awardXp($user, (int) config('tautin.gamification.xp.save', 10));
        $result['leveled_up'] = $result['leveled_up'] || $this->trackMission($user, 'save');
        $this->advanceStreak($user);

        $user->refresh();

        return $this->resultPayload($user, $result['leveled_up']);
    }

    /**
     * Award XP the first time a link is marked as read.
     *
     * @return array{xp: int, level: int, leveled_up: bool, streak_days: int, xp_to_next_level: int}
     */
    public function awardRead(User $user): array
    {
        $result = $this->awardXp($user, (int) config('tautin.gamification.xp.read', 5));
        $result['leveled_up'] = $result['leveled_up'] || $this->trackMission($user, 'read');

        $user->refresh();

        return $this->resultPayload($user, $result['leveled_up']);
    }

    /**
     * Award XP the first time a link is pinned.
     *
     * @return array{xp: int, level: int, leveled_up: bool, streak_days: int, xp_to_next_level: int}
     */
    public function awardPin(User $user): array
    {
        $result = $this->awardXp($user, (int) config('tautin.gamification.xp.pin', 3));

        $user->refresh();

        return $this->resultPayload($user, $result['leveled_up']);
    }

    /**
     * Payload for `GET /api/v1/gamification/summary`.
     *
     * @return array{
     *     xp: int,
     *     level: int,
     *     title: string,
     *     streak_days: int,
     *     xp_to_next_level: int,
     *     level_progress_percent: int,
     *     missions: list<array{
     *         key: string,
     *         label: string,
     *         period_type: string,
     *         progress: int,
     *         target: int,
     *         xp_reward: int,
     *         is_completed: bool
     *     }>
     * }
     */
    public function summary(User $user): array
    {
        $user->refresh();

        return [
            'xp' => $user->xp,
            'level' => $user->level,
            'title' => $user->levelTitle(),
            'streak_days' => $user->streak_days,
            'xp_to_next_level' => $this->xpToNextLevel($user),
            'level_progress_percent' => $this->levelProgressPercent($user),
            'missions' => $this->missionPayload($user),
        ];
    }

    /**
     * Add XP and recompute the derived level.
     *
     * @return array{leveled_up: bool}
     */
    private function awardXp(User $user, int $amount): array
    {
        if ($amount <= 0) {
            return ['leveled_up' => false];
        }

        return DB::transaction(function () use ($user, $amount): array {
            $previousLevel = $user->level;

            $user->increment('xp', $amount);
            $user->refresh();

            $newLevel = $this->levelForXp($user->xp);
            $leveledUp = $newLevel > $previousLevel;

            if ($leveledUp) {
                $user->forceFill(['level' => $newLevel])->save();
            }

            return ['leveled_up' => $leveledUp];
        });
    }

    /**
     * Increase every active mission tracking `$track` and grant the reward when
     * its target is reached.
     *
     * @return bool Whether a mission completion pushed the user to a new level.
     */
    private function trackMission(User $user, string $track): bool
    {
        /** @var list<array{key: string, period_type: string, target: int, xp_reward?: int, label?: string, track?: string}> $definitions */
        $definitions = config('tautin.gamification.missions', []);

        foreach ($definitions as $definition) {
            if (($definition['track'] ?? null) !== $track) {
                continue;
            }

            $periodStart = $this->periodStart($definition['period_type']);

            $mission = UserMission::firstOrCreate(
                [
                    'user_id' => $user->id,
                    'mission_key' => $definition['key'],
                    'period_start' => $periodStart,
                ],
                [
                    'period_type' => $definition['period_type'],
                    'target' => $definition['target'],
                    'progress' => 0,
                    'xp_reward' => $definition['xp_reward'] ?? config('tautin.gamification.xp.mission', 20),
                    'is_completed' => false,
                ]
            );

            if ($mission->is_completed) {
                continue;
            }

            $mission->increment('progress');

            if ($mission->fresh()->progress < $mission->target) {
                continue;
            }

            $mission->forceFill([
                'is_completed' => true,
                'completed_at' => now(),
            ])->save();

            $result = $this->awardXp($user, $mission->xp_reward);

            if ($result['leveled_up']) {
                return true;
            }
        }

        return false;
    }

    /**
     * Advance (or reset) the daily save streak in WIB.
     */
    private function advanceStreak(User $user): void
    {
        $today = $this->now()->startOfDay();

        // `streak_last_date` is cast in the app timezone (usually UTC), so
        // comparing it directly with a WIB midnight yields a fractional day
        // and truncates to 0. Rebuild both ends as WIB calendar dates.
        $lastDate = $user->streak_last_date === null
            ? null
            : CarbonImmutable::parse(
                $user->streak_last_date->toDateString(),
                $this->timezone()
            )->startOfDay();

        if ($lastDate === null) {
            $user->forceFill([
                'streak_days' => 1,
                'streak_last_date' => $today->toDateString(),
                'streak_shields_used' => 0,
            ])->save();

            return;
        }

        if ($lastDate->equalTo($today)) {
            return;
        }

        $missedDays = (int) $lastDate->diffInDays($today);

        // The weekly shield budget resets whenever the week turns over.
        $shieldsUsed = $lastDate->isoWeek() === $today->isoWeek()
            && $lastDate->isoWeekYear() === $today->isoWeekYear()
                ? $user->streak_shields_used
                : 0;

        $shieldBudget = $this->streakShieldBudget($user);

        if ($missedDays === 1) {
            $user->forceFill([
                'streak_days' => max(1, $user->streak_days) + 1,
                'streak_last_date' => $today->toDateString(),
                'streak_shields_used' => $shieldsUsed,
            ])->save();

            return;
        }

        $forgiven = $missedDays === 2 && $shieldsUsed < $shieldBudget;

        $user->forceFill([
            'streak_days' => $forgiven ? max(1, $user->streak_days) + 1 : 1,
            'streak_last_date' => $today->toDateString(),
            'streak_shields_used' => $forgiven ? $shieldsUsed + 1 : 0,
        ])->save();
    }

    /**
     * How many missed days the user may forgive this week (Pro gets more).
     */
    private function streakShieldBudget(User $user): int
    {
        /** @var array<string, int> $budgets */
        $budgets = config('tautin.gamification.streak_shields_per_week', []);

        return max(0, $budgets[$user->isPro() ? 'pro' : 'free'] ?? 0);
    }

    /**
     * @return list<array{
     *     key: string,
     *     label: string,
     *     period_type: string,
     *     progress: int,
     *     target: int,
     *     xp_reward: int,
     *     is_completed: bool
     * }>
     */
    private function missionPayload(User $user): array
    {
        /** @var list<array{key: string, period_type: string, target: int, xp_reward?: int, label?: string, track?: string}> $definitions */
        $definitions = config('tautin.gamification.missions', []);

        $payload = [];

        foreach ($definitions as $definition) {
            $mission = UserMission::firstOrCreate(
                [
                    'user_id' => $user->id,
                    'mission_key' => $definition['key'],
                    'period_start' => $this->periodStart($definition['period_type']),
                ],
                [
                    'period_type' => $definition['period_type'],
                    'target' => $definition['target'],
                    'progress' => 0,
                    'xp_reward' => $definition['xp_reward'] ?? config('tautin.gamification.xp.mission', 20),
                    'is_completed' => false,
                ]
            );

            $payload[] = [
                'key' => $mission->mission_key,
                'label' => $definition['label'] ?? $definition['key'],
                'period_type' => $mission->period_type,
                'progress' => $mission->progress,
                'target' => $mission->target,
                'xp_reward' => $mission->xp_reward,
                'is_completed' => $mission->is_completed,
            ];
        }

        return $payload;
    }

    /**
     * Start date of the current mission period in WIB.
     */
    private function periodStart(string $periodType): string
    {
        $now = $this->now();

        if ($periodType === 'weekly') {
            return $now->startOfWeek(CarbonImmutable::MONDAY)->toDateString();
        }

        return $now->toDateString();
    }

    private function levelForXp(int $xp): int
    {
        $step = max(1, (int) config('tautin.gamification.level_step', 100));

        return intdiv($xp, $step) + 1;
    }

    private function xpToNextLevel(User $user): int
    {
        $step = max(1, (int) config('tautin.gamification.level_step', 100));

        return $step - ($user->xp % $step);
    }

    private function levelProgressPercent(User $user): int
    {
        $step = max(1, (int) config('tautin.gamification.level_step', 100));

        return (int) round((($user->xp % $step) / $step) * 100);
    }

    /**
     * @return array{xp: int, level: int, leveled_up: bool, streak_days: int, xp_to_next_level: int}
     */
    private function resultPayload(User $user, bool $leveledUp): array
    {
        return [
            'xp' => $user->xp,
            'level' => $user->level,
            'leveled_up' => $leveledUp,
            'streak_days' => $user->streak_days,
            'xp_to_next_level' => $this->xpToNextLevel($user),
        ];
    }

    private function now(): CarbonImmutable
    {
        return CarbonImmutable::now($this->timezone());
    }

    /**
     * Timezone every streak and mission period is computed in (PRD FR-GAME-03).
     */
    private function timezone(): string
    {
        return (string) config('tautin.gamification.timezone', 'Asia/Jakarta');
    }
}
