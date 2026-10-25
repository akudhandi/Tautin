<?php

namespace App\Services\Scraper;

use App\Services\Scraper\Data\ScrapedMetadata;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Symfony\Component\DomCrawler\Crawler;

class HtmlDomExtractor
{
    /**
     * Max download stream limit: 1.5 MB.
     */
    protected const MAX_BYTES = 1572864;

    /**
     * Extract metadata and clean text from HTML OpenGraph & DOM.
     */
    public function extract(string $canonicalUrl, string $domain): ?ScrapedMetadata
    {
        try {
            $response = Http::withOptions([
                'timeout' => 8,
                'connect_timeout' => 4,
                'headers' => [
                    'User-Agent' => 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
                    'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    'Accept-Language' => 'id-ID,id;q=0.9,en-US;q=0.8',
                ],
            ])->get($canonicalUrl);

            if (! $response->successful()) {
                return null;
            }

            $contentType = $response->header('Content-Type') ?? '';
            if (! str_contains(strtolower($contentType), 'text/html') && ! str_contains(strtolower($contentType), 'application/xhtml+xml')) {
                return null;
            }

            $body = (string) $response->body();
            if (strlen($body) > self::MAX_BYTES) {
                $body = substr($body, 0, self::MAX_BYTES);
            }

            if (empty(trim($body))) {
                return null;
            }

            $crawler = new Crawler($body, $canonicalUrl);

            // 1. Title
            $title = $this->extractMeta($crawler, ['og:title', 'twitter:title']);
            if (empty($title)) {
                $titleNode = $crawler->filter('title');
                if ($titleNode->count() > 0) {
                    $title = trim($titleNode->first()->text());
                }
            }

            // 2. Thumbnail
            $thumbnailUrl = $this->extractMeta($crawler, ['og:image', 'twitter:image', 'thumbnail']);
            if (! empty($thumbnailUrl)) {
                $thumbnailUrl = $this->resolveAbsoluteUrl($canonicalUrl, $thumbnailUrl);
            }

            // 3. Description
            $description = $this->extractMeta($crawler, ['og:description', 'twitter:description', 'description']);

            // 4. Clean Body Text
            $bodyExcerpt = $this->extractCleanBodyText($crawler);

            // 5. Source Type Classification
            $sourceType = $this->detectSourceType($domain, $crawler);

            if (empty($title) && empty($description) && empty($bodyExcerpt)) {
                return null;
            }

            return new ScrapedMetadata(
                canonicalUrl: $canonicalUrl,
                domain: $domain,
                title: $title ? mb_substr($title, 0, 255) : null,
                thumbnailUrl: $thumbnailUrl,
                description: $description,
                bodyExcerpt: $bodyExcerpt,
                sourceType: $sourceType,
                isFallback: false
            );
        } catch (\Throwable $e) {
            Log::info('HTML DOM extraction failed', ['url' => $canonicalUrl, 'error' => $e->getMessage()]);

            return null;
        }
    }

    /**
     * Extract meta content from property or name attributes.
     *
     * @param  list<string>  $keys
     */
    protected function extractMeta(Crawler $crawler, array $keys): ?string
    {
        foreach ($keys as $key) {
            $nodes = $crawler->filter("meta[property='{$key}'], meta[name='{$key}']");
            if ($nodes->count() > 0) {
                $content = $nodes->first()->attr('content');
                if (! empty($content)) {
                    return trim($content);
                }
            }
        }

        return null;
    }

    /**
     * Extract clean readable text from main article tags (max 3,000 chars).
     */
    protected function extractCleanBodyText(Crawler $crawler): ?string
    {
        try {
            // Remove noise elements
            $html = $crawler->html();
            $cleanedHtml = preg_replace('/<(script|style|nav|header|footer|aside|noscript|iframe)[^>]*>.*?<\/\\1>/si', '', $html);

            if (! $cleanedHtml) {
                return null;
            }

            $cleanCrawler = new Crawler($cleanedHtml);

            // Look for article or main first
            $articleNodes = $cleanCrawler->filter('article, main, [role="main"]');
            $text = '';

            if ($articleNodes->count() > 0) {
                $text = $articleNodes->first()->text();
            } else {
                // Collect paragraphs
                $pNodes = $cleanCrawler->filter('p');
                if ($pNodes->count() > 0) {
                    $paragraphs = [];
                    foreach ($pNodes as $node) {
                        $pText = trim($node->textContent);
                        if (strlen($pText) > 20) {
                            $paragraphs[] = $pText;
                        }
                    }
                    $text = implode("\n", array_slice($paragraphs, 0, 10));
                }
            }

            $normalized = trim(preg_replace('/\s+/', ' ', $text) ?? '');
            if (empty($normalized)) {
                return null;
            }

            return mb_substr($normalized, 0, 3000);
        } catch (\Throwable) {
            return null;
        }
    }

    /**
     * Detect source type from domain or page markup.
     *
     * @return 'video'|'ecommerce'|'article'|'social'|'other'
     */
    protected function detectSourceType(string $domain, Crawler $crawler): string
    {
        $domain = strtolower($domain);

        if (str_contains($domain, 'shopee.') || str_contains($domain, 'tokopedia.') || str_contains($domain, 'lazada.') || str_contains($domain, 'blibli.')) {
            return 'ecommerce';
        }

        if (str_contains($domain, 'youtube.') || str_contains($domain, 'youtu.be') || str_contains($domain, 'tiktok.')) {
            return 'video';
        }

        if (str_contains($domain, 'instagram.') || str_contains($domain, 'facebook.') || str_contains($domain, 'threads.') || str_contains($domain, 'x.com') || str_contains($domain, 'twitter.')) {
            return 'social';
        }

        $ogType = $this->extractMeta($crawler, ['og:type']);
        if ($ogType === 'article') {
            return 'article';
        }
        if (str_starts_with((string) $ogType, 'video')) {
            return 'video';
        }

        return 'article';
    }

    /**
     * Resolve relative image URL to absolute URL.
     */
    protected function resolveAbsoluteUrl(string $baseUrl, string $relativeUrl): string
    {
        $relativeUrl = trim($relativeUrl);

        if (str_starts_with($relativeUrl, 'http://') || str_starts_with($relativeUrl, 'https://')) {
            return $relativeUrl;
        }

        if (str_starts_with($relativeUrl, '//')) {
            $scheme = parse_url($baseUrl, PHP_URL_SCHEME) ?? 'https';

            return $scheme.':'.$relativeUrl;
        }

        $parts = parse_url($baseUrl);
        $base = ($parts['scheme'] ?? 'https').'://'.($parts['host'] ?? '');

        if (! empty($parts['port'])) {
            $base .= ':'.$parts['port'];
        }

        if (str_starts_with($relativeUrl, '/')) {
            return $base.$relativeUrl;
        }

        $currentPath = $parts['path'] ?? '/';
        $dir = dirname($currentPath);
        if ($dir === '\\' || $dir === '.') {
            $dir = '';
        }

        return $base.'/'.ltrim($dir.'/'.$relativeUrl, '/');
    }
}
