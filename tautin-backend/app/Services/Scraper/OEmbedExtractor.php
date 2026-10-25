<?php

namespace App\Services\Scraper;

use App\Services\Scraper\Data\ScrapedMetadata;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class OEmbedExtractor
{
    /**
     * Determine if the domain is supported by official oEmbed endpoints.
     */
    public function canExtract(string $domain): bool
    {
        $domain = strtolower($domain);

        return str_contains($domain, 'youtube.com')
            || str_contains($domain, 'youtu.be')
            || str_contains($domain, 'tiktok.com')
            || str_contains($domain, 'twitter.com')
            || str_contains($domain, 'x.com');
    }

    /**
     * Extract metadata from official oEmbed endpoints.
     */
    public function extract(string $canonicalUrl, string $domain): ?ScrapedMetadata
    {
        $domain = strtolower($domain);
        $endpoint = $this->resolveEndpoint($canonicalUrl, $domain);

        if (! $endpoint) {
            return null;
        }

        try {
            $response = Http::withOptions([
                'timeout' => 5,
                'connect_timeout' => 3,
            ])->get($endpoint);

            if (! $response->successful()) {
                return null;
            }

            $data = $response->json();
            if (! is_array($data)) {
                return null;
            }

            $sourceType = 'other';
            if (str_contains($domain, 'youtube.com') || str_contains($domain, 'youtu.be') || str_contains($domain, 'tiktok.com')) {
                $sourceType = 'video';
            } elseif (str_contains($domain, 'twitter.com') || str_contains($domain, 'x.com')) {
                $sourceType = 'social';
            }

            $title = $data['title'] ?? null;
            $thumbnailUrl = $data['thumbnail_url'] ?? null;
            $description = null;

            if (empty($title) && ! empty($data['author_name'])) {
                $title = 'Postingan oleh '.$data['author_name'];
            }

            // For Twitter, if title is empty or generic, extract text from html block
            if ($sourceType === 'social' && ! empty($data['html'])) {
                $cleanedText = strip_tags($data['html']);
                $description = trim(preg_replace('/\s+/', ' ', $cleanedText) ?? '');
                if (empty($title)) {
                    $title = mb_substr($description, 0, 100);
                }
            }

            if (empty($title) && empty($thumbnailUrl)) {
                return null;
            }

            return new ScrapedMetadata(
                canonicalUrl: $canonicalUrl,
                domain: $domain,
                title: $title,
                thumbnailUrl: $thumbnailUrl,
                description: $description ?? ($data['author_name'] ?? null),
                bodyExcerpt: $description,
                sourceType: $sourceType,
                isFallback: false
            );
        } catch (\Throwable $e) {
            Log::info('oEmbed extraction failed', ['url' => $canonicalUrl, 'error' => $e->getMessage()]);

            return null;
        }
    }

    /**
     * Resolve the oEmbed endpoint URL.
     */
    protected function resolveEndpoint(string $url, string $domain): ?string
    {
        $encoded = urlencode($url);

        if (str_contains($domain, 'youtube.com') || str_contains($domain, 'youtu.be')) {
            return "https://www.youtube.com/oembed?url={$encoded}&format=json";
        }

        if (str_contains($domain, 'tiktok.com')) {
            return "https://www.tiktok.com/oembed?url={$encoded}";
        }

        if (str_contains($domain, 'twitter.com') || str_contains($domain, 'x.com')) {
            return "https://publish.twitter.com/oembed?url={$encoded}";
        }

        return null;
    }
}
