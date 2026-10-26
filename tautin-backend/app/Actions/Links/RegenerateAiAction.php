<?php

namespace App\Actions\Links;

use App\Exceptions\BusinessLogicException;
use App\Jobs\ProcessSharedLinkJob;
use App\Models\Link;
use App\Models\User;

class RegenerateAiAction
{
    /**
     * Re-run the scraping + AI pipeline for an existing link.
     *
     * Pro/lifetime entitlement messages:
     * - `PRO_REQUIRED_FOR_REGENERATE`: regeneration is a Pro-only feature.
     * - `AI_QUOTA_EXCEEDED`: even Pro/lifetime users have the monthly
     *   500/month fair-use summary quota.
     *
     * @throws BusinessLogicException
     */
    public function execute(User $user, int $linkId): Link
    {
        if (! $user->isPro()) {
            throw new BusinessLogicException(
                errorCode: 'PRO_REQUIRED_FOR_REGENERATE',
                message: 'Fitur buat ulang ringkasan AI khusus untuk pengguna Tautin Pro.',
                httpStatus: 403
            );
        }

        if (! $user->hasAiQuota()) {
            throw new BusinessLogicException(
                errorCode: 'AI_QUOTA_EXCEEDED',
                message: 'Kuota ringkasan AI bulanan Anda telah habis.',
                httpStatus: 403
            );
        }

        /** @var Link $link */
        $link = $user->links()->findOrFail($linkId);

        $link->update(['status' => 'pending']);

        ProcessSharedLinkJob::dispatch($link->id)->onQueue('high');

        return $link->fresh(['collection', 'tags']);
    }
}
