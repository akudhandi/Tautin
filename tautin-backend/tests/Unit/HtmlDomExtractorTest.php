<?php

namespace Tests\Unit;

use App\Services\Scraper\HtmlDomExtractor;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class HtmlDomExtractorTest extends TestCase
{
    protected HtmlDomExtractor $extractor;

    protected function setUp(): void
    {
        parent::setUp();
        $this->extractor = new HtmlDomExtractor;
    }

    public function test_resolves_root_relative_image_path_to_absolute_url(): void
    {
        $baseUrl = 'https://example.com/blog/article-1';
        $relativeUrl = '/images/thumb.jpg';

        $absolute = $this->extractor->resolveAbsoluteUrl($baseUrl, $relativeUrl);
        $this->assertEquals('https://example.com/images/thumb.jpg', $absolute);
    }

    public function test_resolves_directory_relative_image_path_to_absolute_url(): void
    {
        $baseUrl = 'https://example.com/blog/sub/article-1';
        $relativeUrl = '../assets/cover.png';

        $absolute = $this->extractor->resolveAbsoluteUrl($baseUrl, $relativeUrl);
        $this->assertEquals('https://example.com/blog/assets/cover.png', $absolute);
    }

    public function test_resolves_protocol_relative_image_url(): void
    {
        $baseUrl = 'https://example.com/article';
        $relativeUrl = '//cdn.example.com/images/banner.webp';

        $absolute = $this->extractor->resolveAbsoluteUrl($baseUrl, $relativeUrl);
        $this->assertEquals('https://cdn.example.com/images/banner.webp', $absolute);
    }

    public function test_rejects_non_html_content_type(): void
    {
        Http::fake([
            'https://example.com/huge-video.mp4' => Http::response(
                'binary-data',
                200,
                ['Content-Type' => 'video/mp4']
            ),
        ]);

        $result = $this->extractor->extract('https://example.com/huge-video.mp4', 'example.com');
        $this->assertNull($result);
    }

    public function test_extracts_html_metadata_with_relative_og_image(): void
    {
        $html = <<<'HTML'
<!DOCTYPE html>
<html>
<head>
    <meta property="og:title" content="Judul Artikel Menarik">
    <meta property="og:image" content="/images/thumb.jpg">
    <meta property="og:description" content="Deskripsi artikel untuk pengujian">
</head>
<body>
    <article><p>Isi artikel yang cukup panjang untuk dibaca.</p></article>
</body>
</html>
HTML;

        Http::fake([
            'https://example.com/post/1' => Http::response(
                $html,
                200,
                ['Content-Type' => 'text/html; charset=UTF-8']
            ),
        ]);

        $result = $this->extractor->extract('https://example.com/post/1', 'example.com');

        $this->assertNotNull($result);
        $this->assertEquals('Judul Artikel Menarik', $result->title);
        $this->assertEquals('https://example.com/images/thumb.jpg', $result->thumbnailUrl);
    }
}
