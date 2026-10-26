<?php

namespace App\Jobs;

use App\Exceptions\UnsafeUrlException;
use App\Models\Link;
use App\Models\Tag;
use App\Services\AI\GeminiOrganizerService;
use App\Services\Scraper\MultiLayerScraperService;
use App\Services\Scraper\SsrfGuard;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ProcessSharedLinkJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * The number of times the job may be attempted.
     */
    public int $tries = 2;

    /**
     * The number of seconds the job can run before timing out.
     */
    public int $timeout = 25;

    public function __construct(
        public int $linkId
    ) {}

    /**
     * Execute the job.
     */
    public function handle(
        SsrfGuard $ssrfGuard,
        MultiLayerScraperService $scraper,
        GeminiOrganizerService $gemini
    ): void {
        $link = Link::with('user')->find($this->linkId);
        if (! $link) {
            return;
        }

        $link->update(['status' => 'processing']);

        // 1. SSRF Guard & URL Canonicalization
        try {
            $canonicalUrl = $ssrfGuard->validateAndResolve($link->url);
        } catch (UnsafeUrlException $e) {
            Log::warning('Link failed SSRF check', ['link_id' => $link->id, 'url' => $link->url, 'error' => $e->getMessage()]);
            $link->update([
                'status' => 'failed',
                'title' => 'Tautan tidak dapat diproses: '.$e->getMessage(),
            ]);

            return;
        } catch (\Throwable $e) {
            Log::error('Canonicalization error', ['link_id' => $link->id, 'error' => $e->getMessage()]);
            $canonicalUrl = $link->url;
        }

        // Handle canonical URL hash collision with another existing link of the same user
        $canonicalHash = hash('sha256', $canonicalUrl);
        if ($canonicalHash !== $link->url_hash) {
            $existing = Link::where('user_id', $link->user_id)
                ->where('url_hash', $canonicalHash)
                ->where('id', '!=', $link->id)
                ->first();

            if ($existing) {
                $existing->touch();
                if (! empty($link->user_notes) && empty($existing->user_notes)) {
                    $existing->update(['user_notes' => $link->user_notes]);
                }
                $link->delete();

                return;
            }

            $link->url = $canonicalUrl;
            $link->url_hash = $canonicalHash;
            $link->domain = parse_url($canonicalUrl, PHP_URL_HOST) ?? $link->domain;
        }

        // 2. Multi-Layer Scraper
        $metadata = $scraper->scrape($canonicalUrl, $link->domain, $link->raw_description);
        $link->title = $metadata->title;
        $link->thumbnail_url = $metadata->thumbnailUrl;
        $link->source_type = $metadata->sourceType;

        // 3. AI Analysis & Auto-Organization
        $user = $link->user;
        $aiEligible = $user && $user->hasAiQuota();
        $aiApplied = false;

        if ($aiEligible) {
            $aiResult = $gemini->analyze($link, $user, $metadata);

            if ($aiResult !== null) {
                $link->title = $aiResult->cleanTitle;
                $link->ai_summary = $aiResult->summary;
                $link->source_type = $aiResult->sourceType;
                $link->is_ai_processed = true;
                $aiApplied = true;

                // Auto-Folder Mapping if not selected manually (case-insensitive)
                if ($link->collection_id === null) {
                    $targetName = mb_strtolower(trim($aiResult->selectedCollectionName));
                    $matched = $user->collections->first(function ($col) use ($targetName) {
                        return mb_strtolower(trim($col->name)) === $targetName;
                    });

                    if ($matched) {
                        $link->collection_id = $matched->id;
                    }
                }

                // Sync Tags
                if (! empty($aiResult->tags)) {
                    $tagIds = [];
                    foreach ($aiResult->tags as $tagName) {
                        $tag = Tag::firstOrCreate([
                            'user_id' => $user->id,
                            'name' => $tagName,
                        ]);
                        $tagIds[] = $tag->id;
                    }
                    $link->tags()->sync($tagIds);
                }
            }
        }

        // 4. Fallback default collection if still unassigned
        if ($link->collection_id === null && $user) {
            $defaultCol = $user->collections()
                ->orderBy('is_default', 'desc')
                ->orderBy('sort_order', 'asc')
                ->first();
            if ($defaultCol) {
                $link->collection_id = $defaultCol->id;
            }
        }

        $link->status = 'completed';

        try {
            $link->save();
        } catch (QueryException $e) {
            $existing = Link::where('user_id', $link->user_id)
                ->where('url_hash', $link->url_hash)
                ->where('id', '!=', $link->id)
                ->first();

            if ($existing) {
                $existing->touch();
                if (! empty($link->user_notes) && empty($existing->user_notes)) {
                    $existing->update(['user_notes' => $link->user_notes]);
                }
                $link->delete();

                return;
            }

            throw $e;
        }

        // Decrement quota AFTER successful save
        if ($aiApplied && $user) {
            $user->decrement('ai_quota_left');
        }
    }
}
