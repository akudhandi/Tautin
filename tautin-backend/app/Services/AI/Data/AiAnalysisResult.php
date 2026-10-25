<?php

namespace App\Services\AI\Data;

class AiAnalysisResult
{
    /**
     * @param  list<string>  $tags
     * @param  'video'|'ecommerce'|'article'|'social'|'other'  $sourceType
     */
    public function __construct(
        public string $cleanTitle,
        public string $summary,
        public string $selectedCollectionName,
        public array $tags,
        public string $sourceType
    ) {}
}
