<?php

namespace Tests\Feature;

use App\Actions\Auth\SeedDefaultCollectionsAction;
use App\Jobs\ProcessSharedLinkJob;
use App\Models\Collection;
use App\Models\Link;
use App\Models\User;
use App\Services\AI\GeminiOrganizerService;
use App\Services\Scraper\MultiLayerScraperService;
use App\Services\Scraper\SsrfGuard;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class ProcessSharedLinkJobTest extends TestCase
{
    use RefreshDatabase;

    public function test_job_processes_link_with_oembed_and_gemini_ai(): void
    {
        Config::set('tautin.gemini.api_key', 'mock_gemini_key');

        $user = User::create([
            'name' => 'Oscar',
            'email' => 'oscar@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 10,
        ]);
        app(SeedDefaultCollectionsAction::class)->execute($user);

        $link = Link::create([
            'user_id' => $user->id,
            'url' => 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            'url_hash' => hash('sha256', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
            'domain' => 'www.youtube.com',
            'status' => 'pending',
        ]);

        Http::fake([
            'https://www.youtube.com/watch*' => Http::response('<html>YouTube</html>', 200),
            'https://www.youtube.com/oembed*' => Http::response([
                'title' => 'Rick Astley - Never Gonna Give You Up (Official Music Video)',
                'author_name' => 'Rick Astley',
                'thumbnail_url' => 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
            ], 200),
            'https://generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                [
                                    'text' => json_encode([
                                        'clean_title' => 'Rick Astley - Never Gonna Give You Up',
                                        'summary' => 'Video musik legendaris pop 80-an oleh Rick Astley.',
                                        'selected_collection_name' => 'Tontonan & Hiburan',
                                        'tags' => ['musik-80an', 'rick-astley', 'video-musik'],
                                        'source_type' => 'video',
                                    ]),
                                ],
                            ],
                        ],
                    ],
                ],
            ], 200),
        ]);

        app(ProcessSharedLinkJob::class, ['linkId' => $link->id])->handle(
            app(SsrfGuard::class),
            app(MultiLayerScraperService::class),
            app(GeminiOrganizerService::class)
        );

        $link->refresh();
        $user->refresh();

        $this->assertEquals('completed', $link->status);
        $this->assertTrue($link->is_ai_processed);
        $this->assertEquals('Rick Astley - Never Gonna Give You Up', $link->title);
        $this->assertEquals('Video musik legendaris pop 80-an oleh Rick Astley.', $link->ai_summary);
        $this->assertEquals('video', $link->source_type);
        $this->assertEquals('https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg', $link->thumbnail_url);

        $tontonanCol = $user->collections()->where('name', 'Tontonan & Hiburan')->first();
        $this->assertNotNull($tontonanCol);
        $this->assertEquals($tontonanCol->id, $link->collection_id);

        $this->assertCount(3, $link->tags);
        $this->assertContains('musik-80an', $link->tags->pluck('name')->all());

        // Free quota should decrement from 10 to 9
        $this->assertEquals(9, $user->ai_quota_left);
    }

    public function test_job_processes_html_opengraph_for_articles(): void
    {
        Config::set('tautin.gemini.api_key', 'mock_gemini_key');

        $user = User::create([
            'name' => 'Putri',
            'email' => 'putri@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 10,
        ]);
        app(SeedDefaultCollectionsAction::class)->execute($user);

        $link = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/artikel-kesehatan',
            'url_hash' => hash('sha256', 'https://example.com/artikel-kesehatan'),
            'domain' => 'example.com',
            'status' => 'pending',
        ]);

        $htmlContent = <<<'HTML'
<!DOCTYPE html>
<html>
<head>
    <meta property="og:title" content="Manfaat Minum Air Putih Setiap Pagi" />
    <meta property="og:image" content="https://example.com/images/air.jpg" />
    <meta property="og:description" content="Minum air putih saat bangun pagi memiliki segudang manfaat bagi metabolisme tubuh." />
</head>
<body>
    <article>
        <p>Minum segelas air putih hangat setelah bangun tidur membantu membuang racun dan meningkatkan hidrasi sel tubuh.</p>
    </article>
</body>
</html>
HTML;

        Http::fake([
            'https://example.com/artikel-kesehatan' => Http::response($htmlContent, 200, ['Content-Type' => 'text/html']),
            'https://generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                [
                                    'text' => json_encode([
                                        'clean_title' => 'Manfaat Minum Air Putih di Pagi Hari',
                                        'summary' => 'Meningkatkan hidrasi dan metabolisme tubuh dengan rutin minum air hangat di pagi hari.',
                                        'selected_collection_name' => 'Belajar & Referensi',
                                        'tags' => ['kesehatan', 'hidrasi', 'pola-hidup'],
                                        'source_type' => 'article',
                                    ]),
                                ],
                            ],
                        ],
                    ],
                ],
            ], 200),
        ]);

        app(ProcessSharedLinkJob::class, ['linkId' => $link->id])->handle(
            app(SsrfGuard::class),
            app(MultiLayerScraperService::class),
            app(GeminiOrganizerService::class)
        );

        $link->refresh();
        $this->assertEquals('completed', $link->status);
        $this->assertEquals('Manfaat Minum Air Putih di Pagi Hari', $link->title);
        $this->assertEquals('article', $link->source_type);
        $this->assertEquals('https://example.com/images/air.jpg', $link->thumbnail_url);
    }

    public function test_job_falls_back_when_site_blocks_with_403_forbidden(): void
    {
        // No Gemini key to test pure scraper fallback behavior
        Config::set('tautin.gemini.api_key', null);

        $user = User::create([
            'name' => 'Qori',
            'email' => 'qori@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 10,
        ]);
        app(SeedDefaultCollectionsAction::class)->execute($user);

        $link = Link::create([
            'user_id' => $user->id,
            'url' => 'https://shopee.co.id/sepatu-sneakers-pria-i.12345',
            'url_hash' => hash('sha256', 'https://shopee.co.id/sepatu-sneakers-pria-i.12345'),
            'domain' => 'shopee.co.id',
            'raw_description' => 'Temukan Sepatu Sneakers Pria hanya di Shopee!',
            'status' => 'pending',
        ]);

        Http::fake([
            'https://shopee.co.id/*' => Http::response('Access Denied', 403),
        ]);

        app(ProcessSharedLinkJob::class, ['linkId' => $link->id])->handle(
            app(SsrfGuard::class),
            app(MultiLayerScraperService::class),
            app(GeminiOrganizerService::class)
        );

        $link->refresh();
        $this->assertEquals('completed', $link->status);
        $this->assertEquals('Temukan Sepatu Sneakers Pria hanya di Shopee!', $link->title);
        $this->assertEquals('ecommerce', $link->source_type);
        $this->assertFalse($link->is_ai_processed);
    }

    public function test_job_skips_ai_when_quota_exhausted(): void
    {
        Config::set('tautin.gemini.api_key', 'mock_gemini_key');

        $user = User::create([
            'name' => 'Rina',
            'email' => 'rina@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 0, // Kuota habis!
        ]);
        app(SeedDefaultCollectionsAction::class)->execute($user);

        $link = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/berita-baru',
            'url_hash' => hash('sha256', 'https://example.com/berita-baru'),
            'domain' => 'example.com',
            'status' => 'pending',
        ]);

        Http::fake([
            'https://example.com/berita-baru' => Http::response('<html><title>Berita Terkini Hari Ini</title></html>', 200, ['Content-Type' => 'text/html']),
        ]);

        app(ProcessSharedLinkJob::class, ['linkId' => $link->id])->handle(
            app(SsrfGuard::class),
            app(MultiLayerScraperService::class),
            app(GeminiOrganizerService::class)
        );

        $link->refresh();
        $user->refresh();

        $this->assertEquals('completed', $link->status);
        $this->assertFalse($link->is_ai_processed);
        $this->assertNull($link->ai_summary);
        $this->assertEquals('Berita Terkini Hari Ini', $link->title);
        $this->assertEquals(0, $user->ai_quota_left);

        // Assigned to default collection
        $this->assertNotNull($link->collection_id);
    }

    public function test_job_merges_duplicate_when_shortlink_redirects_to_existing_canonical(): void
    {
        $user = User::create([
            'name' => 'Surya',
            'email' => 'surya@example.com',
            'plan_type' => 'free',
        ]);

        $canonicalUrl = 'https://example.com/resep-nasi-goreng';
        $canonicalHash = hash('sha256', $canonicalUrl);

        // Pre-existing link in user database
        $existingLink = Link::create([
            'user_id' => $user->id,
            'url' => $canonicalUrl,
            'url_hash' => $canonicalHash,
            'domain' => 'example.com',
            'title' => 'Resep Nasi Goreng Spesial',
            'status' => 'completed',
        ]);

        // New shortlink that redirects to the same canonical URL
        $shortlink = 'https://example.com/s/nasgor';
        $shortlinkHash = hash('sha256', $shortlink);

        $newPendingLink = Link::create([
            'user_id' => $user->id,
            'url' => $shortlink,
            'url_hash' => $shortlinkHash,
            'domain' => 'example.com',
            'user_notes' => 'Catatan baru dari share kedua',
            'status' => 'pending',
        ]);

        Http::fake([
            'https://example.com/s/nasgor' => Http::response('', 301, [
                'Location' => $canonicalUrl,
            ]),
            'https://example.com/resep-nasi-goreng' => Http::response('<html>OK</html>', 200, ['Content-Type' => 'text/html']),
        ]);

        app(ProcessSharedLinkJob::class, ['linkId' => $newPendingLink->id])->handle(
            app(SsrfGuard::class),
            app(MultiLayerScraperService::class),
            app(GeminiOrganizerService::class)
        );

        // The pending row should be cleaned up
        $this->assertDatabaseMissing('links', ['id' => $newPendingLink->id]);

        // The existing row should retain and update notes
        $existingLink->refresh();
        $this->assertEquals('Catatan baru dari share kedua', $existingLink->user_notes);
    }
}
