<?php

namespace App\Services\Scraper\Data;

class ScrapedMetadata
{
    /**
     * @param  'video'|'ecommerce'|'article'|'social'|'other'  $sourceType
     */
    public function __construct(
        public string $canonicalUrl,
        public string $domain,
        public ?string $title = null,
        public ?string $thumbnailUrl = null,
        public ?string $description = null,
        public ?string $bodyExcerpt = null,
        public string $sourceType = 'other',
        public bool $isFallback = false
    ) {}
}
