<?php

namespace App\Actions\Links;

use App\Exceptions\BusinessLogicException;
use App\Models\Link;
use App\Models\User;
use App\Services\Gamification\XpLevelService;

class UpdateLinkAction
{
    public function __construct(private readonly XpLevelService $xpLevelService) {}

    /**
     * Update link properties respecting Pro tier boundaries.
     *
     * @param  array{collection_id?: ?int, title?: ?string, user_notes?: ?string, is_pinned?: ?bool, is_read?: ?bool, remind_at?: ?string}  $data
     *
     * @throws BusinessLogicException
     */
    public function execute(User $user, Link $link, array $data): Link
    {
        // 1. Pro Guard for custom reminder
        if (array_key_exists('remind_at', $data) && $data['remind_at'] !== null) {
            if (! $user->isPro()) {
                throw new BusinessLogicException(
                    errorCode: 'PRO_REQUIRED_FOR_REMINDER',
                    message: 'Fitur pengingat jadwal kustom khusus untuk pengguna Tautin Pro.',
                    httpStatus: 403
                );
            }

            $data['reminder_sent'] = false;
        }

        // 2. Validate collection ownership if collection_id is being updated
        if (array_key_exists('collection_id', $data) && $data['collection_id'] !== null) {
            $userCollection = $user->collections()->where('id', $data['collection_id'])->first();
            if (! $userCollection) {
                throw new BusinessLogicException(
                    errorCode: 'COLLECTION_NOT_FOUND',
                    message: 'Koleksi yang dipilih bukan milik akunmu.',
                    httpStatus: 404
                );
            }
        }

        // Capture the pre-update state so XP is granted once per link only
        // (PRD FR-GAME-01 AC-3).
        $readXpAwarded = (bool) $link->read_xp_awarded;
        $pinXpAwarded = (bool) $link->pin_xp_awarded;

        $link->update($data);

        $becameRead = array_key_exists('is_read', $data)
            && (bool) $data['is_read'] === true
            && ! $readXpAwarded;

        $becamePinned = array_key_exists('is_pinned', $data)
            && (bool) $data['is_pinned'] === true
            && ! $pinXpAwarded;

        if ($becameRead) {
            $link->forceFill(['read_xp_awarded' => true])->save();
            $this->xpLevelService->awardRead($user);
        }

        if ($becamePinned) {
            $link->forceFill(['pin_xp_awarded' => true])->save();
            $this->xpLevelService->awardPin($user);
        }

        return $link->fresh(['collection', 'tags']);
    }
}
