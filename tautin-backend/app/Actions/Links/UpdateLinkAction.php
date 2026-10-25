<?php

namespace App\Actions\Links;

use App\Exceptions\BusinessLogicException;
use App\Models\Link;
use App\Models\User;

class UpdateLinkAction
{
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

        $link->update($data);

        return $link->fresh(['collection', 'tags']);
    }
}
