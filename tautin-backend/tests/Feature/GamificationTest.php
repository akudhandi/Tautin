<?php

namespace Tests\Feature;

use App\Models\Link;
use App\Models\User;
use App\Models\UserMission;
use App\Services\Gamification\XpLevelService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class GamificationTest extends TestCase
{
    use RefreshDatabase;

    private function makeUser(string $plan = 'free'): User
    {
        return User::create([
            'name' => 'Gami',
            'email' => 'gami-'.uniqid().'@example.com',
            'plan_type' => $plan,
        ]);
    }

    private function saveLink(User $user, string $url): void
    {
        $this->withHeader('Authorization', 'Bearer '.$user->createToken('t')->plainTextToken)
            ->postJson('/api/v1/links/quick-save', ['url' => $url]);
    }

    public function test_summary_endpoint_requires_authentication(): void
    {
        $this->getJson('/api/v1/gamification/summary')->assertStatus(401);
    }

    public function test_new_save_awards_xp_and_starts_the_streak(): void
    {
        Queue::fake();
        $user = $this->makeUser();

        $this->saveLink($user, 'https://example.com/a');

        $user->refresh();
        $this->assertSame(10, $user->xp);
        $this->assertSame(1, $user->level);
        $this->assertSame(1, $user->streak_days);
    }

    public function test_duplicate_save_does_not_award_xp(): void
    {
        Queue::fake();
        $user = $this->makeUser();

        $this->saveLink($user, 'https://example.com/same');
        $this->saveLink($user, 'https://example.com/same');

        $this->assertSame(10, $user->refresh()->xp);
    }

    public function test_completing_the_daily_save_mission_grants_its_reward(): void
    {
        Queue::fake();
        $user = $this->makeUser();

        $this->saveLink($user, 'https://example.com/1');
        $this->saveLink($user, 'https://example.com/2');
        $this->saveLink($user, 'https://example.com/3');

        // 3 saves x 10 XP + 20 XP mission reward.
        $this->assertSame(50, $user->refresh()->xp);

        $mission = UserMission::where('user_id', $user->id)
            ->where('mission_key', 'daily_save_3')
            ->firstOrFail();

        $this->assertTrue($mission->is_completed);
        $this->assertSame(3, $mission->progress);
    }

    public function test_level_up_uses_hundred_xp_steps_and_maps_the_title(): void
    {
        $user = $this->makeUser();
        $user->forceFill(['xp' => 100, 'level' => 1])->save();

        $service = app(XpLevelService::class);
        $service->awardSave($user);

        $user->refresh();
        $this->assertSame(110, $user->xp);
        $this->assertSame(2, $user->level);
        $this->assertSame('Penyimpan Rajin', $user->levelTitle());
    }

    public function test_read_and_pin_award_xp_only_once_per_link(): void
    {
        $user = $this->makeUser();
        $link = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/read-me',
            'url_hash' => hash('sha256', 'https://example.com/read-me'),
            'raw_url_hash' => hash('sha256', 'https://example.com/read-me'),
            'domain' => 'example.com',
            'status' => 'completed',
        ]);

        $token = $user->createToken('t')->plainTextToken;
        $header = ['Authorization' => 'Bearer '.$token];

        $this->withHeaders($header)
            ->patchJson("/api/v1/links/{$link->id}", ['is_read' => true])
            ->assertOk();

        // Toggling read on/off must not farm XP.
        $this->withHeaders($header)
            ->patchJson("/api/v1/links/{$link->id}", ['is_read' => false])
            ->assertOk();
        $this->withHeaders($header)
            ->patchJson("/api/v1/links/{$link->id}", ['is_read' => true])
            ->assertOk();

        $this->withHeaders($header)
            ->patchJson("/api/v1/links/{$link->id}", ['is_pinned' => true])
            ->assertOk();
        $this->withHeaders($header)
            ->patchJson("/api/v1/links/{$link->id}", ['is_pinned' => false])
            ->assertOk();
        $this->withHeaders($header)
            ->patchJson("/api/v1/links/{$link->id}", ['is_pinned' => true])
            ->assertOk();

        // 5 XP read + 3 XP pin, once each, plus the 20 XP reward for
        // completing the daily_read_1 mission the first read triggers.
        $this->assertSame(28, $user->refresh()->xp);
    }

    public function test_streak_advances_on_the_next_day_and_forgives_one_missed_day(): void
    {
        Queue::fake();
        $user = $this->makeUser();

        $this->travelTo(now()->startOfDay()->setTime(9, 0));
        $this->saveLink($user, 'https://example.com/d1');

        $this->travelTo(now()->addDay()->setTime(9, 0));
        $this->saveLink($user, 'https://example.com/d2');

        $this->assertSame(2, $user->refresh()->streak_days);

        // Skip exactly one day: the free plan's weekly shield forgives it.
        $this->travelTo(now()->addDays(2)->setTime(9, 0));
        $this->saveLink($user, 'https://example.com/d4');

        $user->refresh();
        $this->assertSame(3, $user->streak_days);
        $this->assertSame(1, $user->streak_shields_used);
    }

    public function test_streak_resets_when_more_days_are_missed_than_shields_allow(): void
    {
        Queue::fake();
        $user = $this->makeUser();

        $this->travelTo(now()->startOfDay()->setTime(9, 0));
        $this->saveLink($user, 'https://example.com/s1');

        $this->travelTo(now()->addDays(5)->setTime(9, 0));
        $this->saveLink($user, 'https://example.com/s2');

        $user->refresh();
        $this->assertSame(1, $user->streak_days);
        $this->assertSame(0, $user->streak_shields_used);
    }

    public function test_summary_returns_xp_level_title_streak_and_missions(): void
    {
        Queue::fake();
        $user = $this->makeUser();
        $this->saveLink($user, 'https://example.com/summary');

        $token = $user->createToken('t')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/gamification/summary');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'xp' => 10,
                    'level' => 1,
                    'title' => 'Pemula Tautan',
                    'streak_days' => 1,
                    'xp_to_next_level' => 90,
                ],
            ]);

        $missions = $response->json('data.missions');
        $this->assertIsArray($missions);
        $this->assertNotEmpty($missions);

        $dailySave = collect($missions)->firstWhere('key', 'daily_save_3');
        $this->assertSame(1, $dailySave['progress']);
        $this->assertSame(3, $dailySave['target']);
        $this->assertFalse($dailySave['is_completed']);
    }
}
