<?php

namespace App\Actions\Links;

use App\Jobs\ProcessSharedLinkJob;
use App\Models\Link;
use App\Models\User;
use App\Services\Gamification\XpLevelService;
use App\Services\Scraper\SsrfGuard;

class QuickSaveLinkAction
{
    public function __construct(private readonly XpLevelService $xpLevelService) {}

    /**
     * Quickly save a link in < 300ms, handle duplicate detection, and dispatch background worker.
     *
     * Duplicate detection is instant thanks to two hashes:
     * - `url_hash`:         canonical/clean hash (updated by ProcessSharedLinkJob after unshortening).
     * - `raw_url_hash`:     hash of the URL exactly as first shared (usually a shortlink), never rewritten.
     * Both are compared against the same normalized incoming URL so a shared
     * shortlink is still detected as a duplicate AFTER the original link has
     * been fully unshortened by the background job.
     *
     * @param  array{url: string, raw_description?: ?string, collection_id?: ?int, user_notes?: ?string}  $data
     * @return array{link: Link, is_duplicate: bool}
     */
    public function execute(User $user, array $data): array
    {
        $normalizedUrl = SsrfGuard::normalizeUrlWithoutNetwork($data['url']);
        $incomingHash = hash('sha256', $normalizedUrl);
        $domain = parse_url($normalizedUrl, PHP_URL_HOST) ?? 'unknown';

        $existing = Link::where('user_id', $user->id)
            ->where(function ($query) use ($incomingHash): void {
                $query->where('url_hash', $incomingHash)
                    ->orWhere('raw_url_hash', $incomingHash);
            })
            ->first();

        if ($existing) {
            $existing->touch();

            if (! empty($data['user_notes']) && empty($existing->user_notes)) {
                $existing->update(['user_notes' => $data['user_notes']]);
            }

            return [
                'link' => $existing->load('collection', 'tags'),
                'is_duplicate' => true,
            ];
        }

        $link = Link::create([
            'user_id' => $user->id,
            'collection_id' => $data['collection_id'] ?? null,
            'url' => $normalizedUrl,
            'url_hash' => $incomingHash,
            'raw_url_hash' => $incomingHash,
            'domain' => $domain,
            'raw_description' => $data['raw_description'] ?? null,
            'user_notes' => $data['user_notes'] ?? null,
            'status' => 'pending',
            'is_ai_processed' => false,
            'is_pinned' => false,
            'is_read' => false,
        ]);

        ProcessSharedLinkJob::dispatch($link->id)->onQueue('high');

        // Server-side gamification: a brand-new link is the only save that
        // grants XP, so duplicates short-circuit above (PRD FR-GAME-01 AC-3).
        $this->xpLevelService->awardSave($user);

        return [
            'link' => $link->load('collection', 'tags'),
            'is_duplicate' => false,
        ];
    }
}
