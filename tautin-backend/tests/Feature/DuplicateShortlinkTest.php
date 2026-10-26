<?php

namespace Tests\Feature;

use App\Models\Link;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class DuplicateShortlinkTest extends TestCase
{
    use RefreshDatabase;

    public function test_same_shortlink_is_detected_as_duplicate_after_unshorten(): void
    {
        Queue::fake();

        $user = User::create([
            'name' => 'Toni',
            'email' => 'toni@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 10,
        ]);
        $token = $user->createToken('test')->plainTextToken;

        // 1st quick-save: tracking junk is stripped before hashing/storage.
        $shortlink = 'https://VT.TikTok.com/Xk9zA1?utm_source=share&utm_medium=copy';
        $normalizedShortlink = 'https://vt.tiktok.com/Xk9zA1';

        $first = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/links/quick-save', [
                'url' => '  '.$shortlink.'  ',
            ]);

        $first->assertStatus(201)
            ->assertJson([
                'success' => true,
                'meta' => [
                    'is_duplicate' => false,
                ],
            ]);

        /** @var Link $link */
        $link = Link::findOrFail($first->json('data.id'));

        // New rows set both hashes to the hash of the normalized raw URL.
        $this->assertSame($normalizedShortlink, $link->url);
        $this->assertSame(hash('sha256', $normalizedShortlink), $link->url_hash);
        $this->assertSame(hash('sha256', $normalizedShortlink), $link->raw_url_hash);

        // ProcessSharedLinkJob (simulated) unshortened the link: `url` and
        // `url_hash` are rewritten to the canonical target while
        // `raw_url_hash` keeps the original shortlink fingerprint.
        $canonical = 'https://www.tiktok.com/@tautanuser/video/7421123456789';
        $link->update([
            'url' => $canonical,
            'url_hash' => hash('sha256', $canonical),
            'status' => 'completed',
            'title' => 'Video Menarik',
        ]);
        $link->refresh();

        $this->assertSame(hash('sha256', $canonical), $link->url_hash);
        $this->assertSame(hash('sha256', $normalizedShortlink), $link->raw_url_hash);

        // 2nd quick-save of the SAME shortlink hits raw_url_hash instantly.
        $second = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/links/quick-save', [
                'url' => 'https://vt.tiktok.com/Xk9zA1?igshid=abc123',
            ]);

        $second->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $link->id,
                ],
                'meta' => [
                    'is_duplicate' => true,
                ],
            ]);

        // A fresh canonical paste is caught through `url_hash` as well.
        $third = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/links/quick-save', [
                'url' => $canonical.'?_t=1',
            ]);

        $third->assertStatus(200)
            ->assertJson(['meta' => ['is_duplicate' => true]]);
    }

    public function test_new_rows_store_url_hash_and_raw_url_hash_identically(): void
    {
        Queue::fake();

        $user = User::create([
            'name' => 'Sela',
            'email' => 'sela@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 10,
        ]);
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/links/quick-save', [
                'url' => 'https://id.shp.ee/AbCdEfG',
            ]);

        $response->assertStatus(201);

        $this->assertDatabaseHas('links', [
            'user_id' => $user->id,
            'url' => 'https://id.shp.ee/AbCdEfG',
            'url_hash' => hash('sha256', 'https://id.shp.ee/AbCdEfG'),
            'raw_url_hash' => hash('sha256', 'https://id.shp.ee/AbCdEfG'),
        ]);
    }

    public function test_duplicate_detection_is_scoped_per_user(): void
    {
        Queue::fake();

        $userOne = User::create([
            'name' => 'Dino',
            'email' => 'dino@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 10,
        ]);
        $userTwo = User::create([
            'name' => 'Fifi',
            'email' => 'fifi@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 10,
        ]);

        Link::create([
            'user_id' => $userOne->id,
            'url' => 'https://s.shopee.co.id/xyz123',
            'url_hash' => hash('sha256', 'https://www.tiktok.com/@a/video/1'),
            'raw_url_hash' => hash('sha256', 'https://s.shopee.co.id/xyz123'),
            'domain' => 's.shopee.co.id',
            'status' => 'completed',
        ]);

        // A different user sharing the same shortlink must NOT be flagged.
        $response = $this->withHeader('Authorization', 'Bearer '.$userTwo->createToken('test')->plainTextToken)
            ->postJson('/api/v1/links/quick-save', [
                'url' => 'https://s.shopee.co.id/xyz123',
            ]);

        $response->assertStatus(201)
            ->assertJson(['meta' => ['is_duplicate' => false]]);
    }
}
