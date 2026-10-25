<?php

namespace App\Services\Scraper;

use App\Services\Scraper\Data\ScrapedMetadata;

class MultiLayerScraperService
{
    public function __construct(
        protected OEmbedExtractor $oEmbedExtractor,
        protected HtmlDomExtractor $domExtractor
    ) {}

    /**
     * Scrape URL with multi-layer fallback strategy (Tier 1 -> Tier 2 -> Tier 3).
     */
    public function scrape(string $canonicalUrl, string $domain, ?string $rawDescription = null): ScrapedMetadata
    {
        // Tier 1: Official oEmbed Endpoints
        if ($this->oEmbedExtractor->canExtract($domain)) {
            $metadata = $this->oEmbedExtractor->extract($canonicalUrl, $domain);
            if ($metadata !== null && ! empty($metadata->title)) {
                if (empty($metadata->description) && ! empty($rawDescription)) {
                    $metadata->description = $rawDescription;
                }

                return $metadata;
            }
        }

        // Tier 2: OpenGraph & DOM Parsing
        $metadata = $this->domExtractor->extract($canonicalUrl, $domain);
        if ($metadata !== null && ! empty($metadata->title)) {
            if (empty($metadata->description) && ! empty($rawDescription)) {
                $metadata->description = $rawDescription;
            }

            return $metadata;
        }

        // Tier 3: Fallback from raw_description & URL Slug (Shopee/Tokopedia anti-bot resilience)
        return $this->createFallbackMetadata($canonicalUrl, $domain, $rawDescription);
    }

    /**
     * Create Tier 3 fallback metadata when scraping was blocked.
     */
    protected function createFallbackMetadata(string $canonicalUrl, string $domain, ?string $rawDescription): ScrapedMetadata
    {
        $domain = strtolower($domain);
        $sourceType = 'other';

        if (str_contains($domain, 'shopee.') || str_contains($domain, 'tokopedia.') || str_contains($domain, 'lazada.') || str_contains($domain, 'blibli.')) {
            $sourceType = 'ecommerce';
        } elseif (str_contains($domain, 'youtube.') || str_contains($domain, 'youtu.be') || str_contains($domain, 'tiktok.')) {
            $sourceType = 'video';
        } elseif (str_contains($domain, 'instagram.') || str_contains($domain, 'facebook.') || str_contains($domain, 'threads.') || str_contains($domain, 'x.com') || str_contains($domain, 'twitter.')) {
            $sourceType = 'social';
        }

        $title = null;
        if (! empty($rawDescription)) {
            // Take the first line or first 120 chars as title
            $firstLine = trim(strtok($rawDescription, "\r\n") ?: '');
            if (! empty($firstLine)) {
                $title = mb_substr($firstLine, 0, 120);
            }
        }

        if (empty($title)) {
            // Parse path words
            $path = parse_url($canonicalUrl, PHP_URL_PATH) ?? '';
            $segments = array_filter(explode('/', $path));
            $lastSegment = end($segments);

            if ($lastSegment && strlen($lastSegment) > 2) {
                // Remove file extension
                $cleanSlug = preg_replace('/\.[a-zA-Z0-9]+$/', '', $lastSegment) ?? '';
                $slugWords = trim(preg_replace('/[-_+]+/', ' ', $cleanSlug) ?? '');
                if (strlen($slugWords) > 3) {
                    $title = mb_convert_case($slugWords, MB_CASE_TITLE, 'UTF-8');
                }
            }
        }

        if (empty($title)) {
            $title = 'Tautan dari '.$domain;
        }

        return new ScrapedMetadata(
            canonicalUrl: $canonicalUrl,
            domain: $domain,
            title: $title,
            thumbnailUrl: null,
            description: $rawDescription,
            bodyExcerpt: $rawDescription,
            sourceType: $sourceType,
            isFallback: true
        );
    }
}
