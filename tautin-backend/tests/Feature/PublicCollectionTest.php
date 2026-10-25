<?php

namespace Tests\Feature;

use App\Models\Collection;
use App\Models\Link;
use App\Models\Tag;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PublicCollectionTest extends TestCase
{
    use RefreshDatabase;

    public function test_public_collection_view_protects_owner_email_and_user_notes(): void
    {
        $owner = User::create([
            'name' => 'Indra Owner',
            'email' => 'supersecret.owner@example.com', // Must NEVER leak
        ]);

        $collection = Collection::create([
            'user_id' => $owner->id,
            'name' => 'Referensi Skripsi AI',
            'slug' => 'referensi-skripsi-ai-123',
            'is_public' => true,
        ]);

        $link = Link::create([
            'user_id' => $owner->id,
            'collection_id' => $collection->id,
            'url' => 'https://arxiv.org/abs/2301.00000',
            'url_hash' => hash('sha256', 'https://arxiv.org/abs/2301.00000'),
            'domain' => 'arxiv.org',
            'title' => 'Paper AI Terbaru 2026',
            'ai_summary' => 'Ringkasan paper tentang arsitektur model bahasa ringan.',
            'user_notes' => 'Catatan pribadi: Ini rahasia ide skripsi saya jangan disebar!', // Must NEVER leak
            'status' => 'completed',
        ]);

        $tag = Tag::create([
            'user_id' => $owner->id,
            'name' => 'deep-learning',
        ]);
        $link->tags()->attach($tag->id);

        $response = $this->getJson('/api/v1/public/collections/'.$collection->slug);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'name' => 'Referensi Skripsi AI',
                    'slug' => 'referensi-skripsi-ai-123',
                    'owner_name' => 'Indra Owner',
                    'links_count' => 1,
                    'links' => [
                        [
                            'id' => $link->id,
                            'title' => 'Paper AI Terbaru 2026',
                            'tags' => ['deep-learning'],
                        ],
                    ],
                ],
            ]);

        // CRITICAL PRIVACY ASSERTIONS:
        // 1. Owner email must NOT be present anywhere in the JSON response
        $this->assertStringNotContainsString('supersecret.owner@example.com', $response->getContent() ?: '');

        // 2. Private user_notes must NOT be present anywhere in the JSON response
        $this->assertStringNotContainsString('Catatan pribadi: Ini rahasia ide skripsi', $response->getContent() ?: '');
        $response->assertJsonMissing(['user_notes' => 'Catatan pribadi: Ini rahasia ide skripsi saya jangan disebar!']);
    }

    public function test_private_collection_returns_404_not_found(): void
    {
        $owner = User::create([
            'name' => 'Joko',
            'email' => 'joko@example.com',
        ]);

        $collection = Collection::create([
            'user_id' => $owner->id,
            'name' => 'Koleksi Rahasia',
            'slug' => 'koleksi-rahasia-privat',
            'is_public' => false,
        ]);

        $response = $this->getJson('/api/v1/public/collections/'.$collection->slug);

        $response->assertStatus(404)
            ->assertJson([
                'success' => false,
                'error_code' => 'COLLECTION_NOT_FOUND',
            ]);
    }

    public function test_user_can_clone_public_collection(): void
    {
        $owner = User::create([
            'name' => 'Kartika',
            'email' => 'kartika@example.com',
        ]);

        $publicCol = Collection::create([
            'user_id' => $owner->id,
            'name' => 'Kuliner Jogja',
            'slug' => 'kuliner-jogja-top',
            'is_public' => true,
        ]);

        $sourceLink = Link::create([
            'user_id' => $owner->id,
            'collection_id' => $publicCol->id,
            'url' => 'https://example.com/gudeg-yu-djum',
            'url_hash' => hash('sha256', 'https://example.com/gudeg-yu-djum'),
            'domain' => 'example.com',
            'title' => 'Gudeg Yu Djum Legendaris',
            'ai_summary' => 'Gudeg basah khas Wijilan dengan krecek pedas gurih.',
            'status' => 'completed',
        ]);

        $tag = Tag::create([
            'user_id' => $owner->id,
            'name' => 'kuliner-jogja',
        ]);
        $sourceLink->tags()->attach($tag->id);

        $cloner = User::create([
            'name' => 'Lukman',
            'email' => 'lukman@example.com',
            'plan_type' => 'free',
        ]);
        $token = $cloner->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/public/collections/'.$publicCol->slug.'/clone');

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'name' => 'Kuliner Jogja',
                    'is_public' => false,
                    'links_count' => 1,
                ],
            ]);

        $this->assertDatabaseHas('collections', [
            'user_id' => $cloner->id,
            'name' => 'Kuliner Jogja',
            'is_public' => false,
        ]);

        $this->assertDatabaseHas('links', [
            'user_id' => $cloner->id,
            'url' => 'https://example.com/gudeg-yu-djum',
            'title' => 'Gudeg Yu Djum Legendaris',
        ]);

        $this->assertDatabaseHas('tags', [
            'user_id' => $cloner->id,
            'name' => 'kuliner-jogja',
        ]);
    }

    public function test_cloning_respects_free_tier_collection_limit(): void
    {
        $owner = User::create([
            'name' => 'Mega',
            'email' => 'mega@example.com',
        ]);

        $publicCol = Collection::create([
            'user_id' => $owner->id,
            'name' => 'Koleksi Inspirasi',
            'slug' => 'koleksi-inspirasi',
            'is_public' => true,
        ]);

        $freeUser = User::create([
            'name' => 'Nanda',
            'email' => 'nanda@example.com',
            'plan_type' => 'free',
        ]);

        // Max out user's 5 collections
        for ($i = 1; $i <= 5; $i++) {
            Collection::create([
                'user_id' => $freeUser->id,
                'name' => 'Koleksi '.$i,
                'slug' => 'koleksi-'.$i.'-'.$freeUser->id,
            ]);
        }

        $token = $freeUser->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/public/collections/'.$publicCol->slug.'/clone');

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'error_code' => 'COLLECTION_LIMIT_REACHED',
            ]);
    }
}
