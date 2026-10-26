<?php

namespace Tests\Feature;

use App\Models\Collection;
use App\Models\Link;
use App\Models\Tag;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LinkFeedAndSearchTest extends TestCase
{
    use RefreshDatabase;

    public function test_feed_orders_pinned_links_first_then_latest_updated(): void
    {
        $user = User::create([
            'name' => 'Budi',
            'email' => 'budi@example.com',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        $link1 = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/1',
            'url_hash' => hash('sha256', 'https://example.com/1'),
            'domain' => 'example.com',
            'title' => 'Link Biasa 1',
            'is_pinned' => false,
            'updated_at' => Carbon::now()->subMinutes(10),
        ]);

        $link2 = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/2',
            'url_hash' => hash('sha256', 'https://example.com/2'),
            'domain' => 'example.com',
            'title' => 'Link Biasa 2 Terbaru',
            'is_pinned' => false,
            'updated_at' => Carbon::now()->subMinute(),
        ]);

        $linkPinned = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/pinned',
            'url_hash' => hash('sha256', 'https://example.com/pinned'),
            'domain' => 'example.com',
            'title' => 'Link Paling Penting',
            'is_pinned' => true,
            'updated_at' => Carbon::now()->subHours(5),
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links');

        $response->assertStatus(200)
            ->assertJsonPath('data.data.0.id', $linkPinned->id)
            ->assertJsonPath('data.data.1.id', $link2->id)
            ->assertJsonPath('data.data.2.id', $link1->id);
    }

    public function test_feed_filters_by_collection_and_source_type_and_tags(): void
    {
        $user = User::create([
            'name' => 'Citra',
            'email' => 'citra@example.com',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        $collection = Collection::create([
            'user_id' => $user->id,
            'name' => 'Masakan Nusantara',
            'slug' => 'masakan-nusantara',
        ]);

        $linkFood = Link::create([
            'user_id' => $user->id,
            'collection_id' => $collection->id,
            'url' => 'https://youtube.com/watch?v=resep1',
            'url_hash' => hash('sha256', 'https://youtube.com/watch?v=resep1'),
            'domain' => 'youtube.com',
            'source_type' => 'video',
            'title' => 'Resep Rendang Daging Sapi Empuk',
            'is_read' => false,
        ]);

        $tag = Tag::create([
            'user_id' => $user->id,
            'name' => 'rendang',
        ]);
        $linkFood->tags()->attach($tag->id);

        $linkOther = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/berita',
            'url_hash' => hash('sha256', 'https://example.com/berita'),
            'domain' => 'example.com',
            'source_type' => 'article',
            'title' => 'Berita Ekonomi',
            'is_read' => true,
        ]);

        // Filter by collection
        $resCollection = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links?collection_id='.$collection->id);
        $resCollection->assertStatus(200)
            ->assertJsonCount(1, 'data.data')
            ->assertJsonPath('data.data.0.id', $linkFood->id);

        // Filter by source_type
        $resSource = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links?source_type=video');
        $resSource->assertStatus(200)
            ->assertJsonCount(1, 'data.data')
            ->assertJsonPath('data.data.0.id', $linkFood->id);

        // Filter by tag
        $resTag = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links?tag=rendang');
        $resTag->assertStatus(200)
            ->assertJsonCount(1, 'data.data')
            ->assertJsonPath('data.data.0.id', $linkFood->id);
    }

    public function test_contextual_search_matches_ai_summary_and_title(): void
    {
        $user = User::create([
            'name' => 'Dedi',
            'email' => 'dedi@example.com',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        $targetLink = Link::create([
            'user_id' => $user->id,
            'url' => 'https://kompas.com/ekonomi-2026',
            'url_hash' => hash('sha256', 'https://kompas.com/ekonomi-2026'),
            'domain' => 'kompas.com',
            'title' => 'Panduan Investasi Pemula',
            'ai_summary' => 'Strategi alokasi portofolio reksa dana dan obligasi untuk pemula di era inflasi rendah.',
            'user_notes' => 'Catatan: beli saat gajian pertama',
        ]);

        Link::create([
            'user_id' => $user->id,
            'url' => 'https://detik.com/olahraga',
            'url_hash' => hash('sha256', 'https://detik.com/olahraga'),
            'domain' => 'detik.com',
            'title' => 'Hasil Pertandingan Sepak Bola',
            'ai_summary' => 'Skor akhir liga premier inggris matchday ke 10.',
        ]);

        // Search by word in ai_summary: 'reksa'
        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links?search=reksa');

        $response->assertStatus(200)
            ->assertJsonCount(1, 'data.data')
            ->assertJsonPath('data.data.0.id', $targetLink->id);

        // Search by user_notes: 'gajian'
        $responseNotes = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links?search=gajian');

        $responseNotes->assertStatus(200)
            ->assertJsonCount(1, 'data.data')
            ->assertJsonPath('data.data.0.id', $targetLink->id);
    }

    public function test_resurface_returns_empty_array_when_fewer_than_three_eligible(): void
    {
        $user = User::create([
            'name' => 'Eka',
            'email' => 'eka@example.com',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        // Old unread link (eligible)
        $oldUnread1 = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/old1',
            'url_hash' => hash('sha256', 'https://example.com/old1'),
            'domain' => 'example.com',
            'title' => 'Tautan Lama Belum Dibaca 1',
            'is_read' => false,
        ]);
        $oldUnread1->created_at = Carbon::now()->subDays(5);
        $oldUnread1->saveQuietly();

        // Old unread link (eligible)
        $oldUnread2 = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/old2',
            'url_hash' => hash('sha256', 'https://example.com/old2'),
            'domain' => 'example.com',
            'title' => 'Tautan Lama Belum Dibaca 2',
            'is_read' => false,
        ]);
        $oldUnread2->created_at = Carbon::now()->subDays(4);
        $oldUnread2->saveQuietly();

        // Already read (not eligible)
        $readLink = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/already-read',
            'url_hash' => hash('sha256', 'https://example.com/already-read'),
            'domain' => 'example.com',
            'title' => 'Sudah Dibaca',
            'is_read' => true,
        ]);
        $readLink->created_at = Carbon::now()->subDays(10);
        $readLink->saveQuietly();

        // Fresh link (not eligible)
        Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/fresh',
            'url_hash' => hash('sha256', 'https://example.com/fresh'),
            'domain' => 'example.com',
            'title' => 'Tautan Baru Kemarin',
            'is_read' => false,
            'created_at' => Carbon::now()->subHours(12),
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links/resurface');

        // PRD FR-REM-01 AC-1: the resurfacing carousel requires a minimum of
        // 3 eligible links; with only 2 the backend returns an empty list.
        $response->assertStatus(200)
            ->assertExactJson([
                'success' => true,
                'message' => 'Daftar tautan untuk dibaca ulang berhasil dimuat.',
                'data' => [],
            ]);
    }

    public function test_resurface_returns_three_random_links_when_enough_eligible(): void
    {
        $user = User::create([
            'name' => 'Wina',
            'email' => 'wina@example.com',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        $eligibleIds = [];
        $expiredDays = [7, 6, 5];

        foreach ($expiredDays as $index => $days) {
            $link = Link::create([
                'user_id' => $user->id,
                'url' => 'https://example.com/old-resurface-'.$index,
                'url_hash' => hash('sha256', 'https://example.com/old-resurface-'.$index),
                'domain' => 'example.com',
                'title' => 'Tautan Lama Belum Dibaca '.$index,
                'is_read' => false,
            ]);
            $link->created_at = Carbon::now()->subDays($days);
            $link->saveQuietly();
            $eligibleIds[] = $link->id;
        }

        // Fresh or already-read links must never come back.
        Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/fresh-resurface',
            'url_hash' => hash('sha256', 'https://example.com/fresh-resurface'),
            'domain' => 'example.com',
            'title' => 'Tautan Baru',
            'is_read' => false,
        ]);
        Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/read-resurface',
            'url_hash' => hash('sha256', 'https://example.com/read-resurface'),
            'domain' => 'example.com',
            'title' => 'Tautan Sudah Dibaca',
            'is_read' => true,
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links/resurface');

        $returnedIds = collect($response->assertStatus(200)->json('data'))
            ->pluck('id')
            ->values()
            ->all();
        sort($returnedIds);
        sort($eligibleIds);

        $this->assertEquals($eligibleIds, $returnedIds);
    }

    public function test_feed_supports_collection_id_unassigned_filter(): void
    {
        $user = User::create([
            'name' => 'Yuna',
            'email' => 'yuna@example.com',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        $collection = Collection::create([
            'user_id' => $user->id,
            'name' => 'Koleksi Terisi',
            'slug' => 'koleksi-terisi',
        ]);

        $assigned = Link::create([
            'user_id' => $user->id,
            'collection_id' => $collection->id,
            'url' => 'https://example.com/assigned',
            'url_hash' => hash('sha256', 'https://example.com/assigned'),
            'domain' => 'example.com',
            'title' => 'Link Dalam Koleksi',
        ]);

        $orphan = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/orphan',
            'url_hash' => hash('sha256', 'https://example.com/orphan'),
            'domain' => 'example.com',
            'title' => 'Link Tanpa Koleksi',
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links?collection_id=unassigned');

        $response->assertStatus(200)
            ->assertJsonCount(1, 'data.data')
            ->assertJsonPath('data.data.0.id', $orphan->id)
            ->assertJsonMissing(['id' => $assigned->id]);
    }

    public function test_free_user_cannot_set_custom_reminder_returns_403_pro_required(): void
    {
        $freeUser = User::create([
            'name' => 'Fani',
            'email' => 'fani@example.com',
            'plan_type' => 'free',
        ]);
        $token = $freeUser->createToken('test')->plainTextToken;

        $link = Link::create([
            'user_id' => $freeUser->id,
            'url' => 'https://example.com/artikel',
            'url_hash' => hash('sha256', 'https://example.com/artikel'),
            'domain' => 'example.com',
            'title' => 'Artikel Menarik',
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->patchJson('/api/v1/links/'.$link->id, [
                'remind_at' => Carbon::now()->addDays(2)->toDateTimeString(),
            ]);

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'error_code' => 'PRO_REQUIRED_FOR_REMINDER',
            ]);
    }

    public function test_pro_user_can_set_custom_reminder(): void
    {
        $proUser = User::create([
            'name' => 'Gilang',
            'email' => 'gilang@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => Carbon::now()->addMonth(),
        ]);
        $token = $proUser->createToken('test')->plainTextToken;

        $link = Link::create([
            'user_id' => $proUser->id,
            'url' => 'https://example.com/resep-pro',
            'url_hash' => hash('sha256', 'https://example.com/resep-pro'),
            'domain' => 'example.com',
            'title' => 'Resep Premium',
            'reminder_sent' => true,
        ]);

        $remindAt = Carbon::now()->addDays(3)->startOfMinute();

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->patchJson('/api/v1/links/'.$link->id, [
                'remind_at' => $remindAt->toDateTimeString(),
                'is_pinned' => true,
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('data.is_pinned', true)
            ->assertJsonPath('data.reminder_sent', false);

        $link->refresh();
        $this->assertEquals($remindAt->toDateTimeString(), $link->remind_at->toDateTimeString());
        $this->assertFalse($link->reminder_sent);
    }

    public function test_user_can_show_and_delete_link(): void
    {
        $user = User::create([
            'name' => 'Hadi',
            'email' => 'hadi@example.com',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        $link = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/hapus',
            'url_hash' => hash('sha256', 'https://example.com/hapus'),
            'domain' => 'example.com',
            'title' => 'Tautan Dihapus',
        ]);

        // Show
        $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links/'.$link->id)
            ->assertStatus(200)
            ->assertJsonPath('data.id', $link->id);

        // Delete
        $this->withHeader('Authorization', 'Bearer '.$token)
            ->deleteJson('/api/v1/links/'.$link->id)
            ->assertStatus(200);

        $this->assertDatabaseMissing('links', ['id' => $link->id]);
    }

    public function test_feed_clamps_per_page_to_valid_range(): void
    {
        $user = User::create([
            'name' => 'Irfan Page',
            'email' => 'irfan@example.com',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        for ($i = 1; $i <= 5; $i++) {
            Link::create([
                'user_id' => $user->id,
                'url' => 'https://example.com/p'.$i,
                'url_hash' => hash('sha256', 'https://example.com/p'.$i),
                'domain' => 'example.com',
                'title' => 'Page Link '.$i,
            ]);
        }

        // Test upper clamp: per_page=500 should be clamped to 100
        $responseMax = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links?per_page=500');
        $responseMax->assertStatus(200)
            ->assertJsonPath('data.per_page', 100);

        // Test lower clamp: per_page=0 or negative should be clamped to 1
        $responseMin = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/links?per_page=0');
        $responseMin->assertStatus(200)
            ->assertJsonPath('data.per_page', 1);
    }
}
