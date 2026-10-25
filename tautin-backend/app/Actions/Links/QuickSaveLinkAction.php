<?php

namespace App\Actions\Links;

use App\Jobs\ProcessSharedLinkJob;
use App\Models\Link;
use App\Models\User;

class QuickSaveLinkAction
{
    /**
     * Quickly save a link in < 300ms, handle duplicate detection, and dispatch background worker.
     *
     * @param  array{url: string, raw_description?: ?string, collection_id?: ?int, user_notes?: ?string}  $data
     * @return array{link: Link, is_duplicate: bool}
     */
    public function execute(User $user, array $data): array
    {
        $url = trim($data['url']);
        $urlHash = hash('sha256', $url);
        $domain = parse_url($url, PHP_URL_HOST) ?? 'unknown';

        $existing = Link::where('user_id', $user->id)
            ->where('url_hash', $urlHash)
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
            'url' => $url,
            'url_hash' => $urlHash,
            'domain' => $domain,
            'raw_description' => $data['raw_description'] ?? null,
            'user_notes' => $data['user_notes'] ?? null,
            'status' => 'pending',
            'is_ai_processed' => false,
            'is_pinned' => false,
            'is_read' => false,
        ]);

        ProcessSharedLinkJob::dispatch($link->id)->onQueue('high');

        return [
            'link' => $link->load('collection', 'tags'),
            'is_duplicate' => false,
        ];
    }
}
