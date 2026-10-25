<?php

namespace Tests\Feature;

use App\Jobs\ProcessSharedLinkJob;
use App\Models\Collection;
use App\Models\Link;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class QuickSaveLinkTest extends TestCase
{
    use RefreshDatabase;

    public function test_quick_save_creates_pending_link_and_dispatches_job(): void
    {
        Queue::fake();

        $user = User::create([
            'name' => 'Kiki',
            'email' => 'kiki@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 10,
        ]);

        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/links/quick-save', [
                'url' => 'https://id.shp.ee/AbCdEfG',
                'raw_description' => 'Temukan Sepatu Running Pria seharga Rp349.000 hanya di Shopee!',
            ]);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'url' => 'https://id.shp.ee/AbCdEfG',
                    'domain' => 'id.shp.ee',
                    'status' => 'pending',
                ],
                'meta' => [
                    'is_duplicate' => false,
                    'ai_quota_left' => 10,
                ],
            ]);

        $this->assertDatabaseHas('links', [
            'user_id' => $user->id,
            'url' => 'https://id.shp.ee/AbCdEfG',
            'domain' => 'id.shp.ee',
            'status' => 'pending',
            'raw_description' => 'Temukan Sepatu Running Pria seharga Rp349.000 hanya di Shopee!',
        ]);

        Queue::assertPushedOn('high', ProcessSharedLinkJob::class);
    }

    public function test_quick_save_detects_duplicate_url_and_does_not_dispatch_job(): void
    {
        Queue::fake();

        $user = User::create([
            'name' => 'Lina',
            'email' => 'lina@example.com',
            'plan_type' => 'free',
        ]);

        $token = $user->createToken('test')->plainTextToken;

        // First save
        $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/links/quick-save', [
                'url' => 'https://example.com/resep-ayam',
            ])->assertStatus(201);

        Queue::assertPushed(ProcessSharedLinkJob::class, 1);

        // Second save (exact same URL)
        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/links/quick-save', [
                'url' => 'https://example.com/resep-ayam',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'meta' => [
                    'is_duplicate' => true,
                ],
            ]);

        // Job should not be pushed again
        Queue::assertPushed(ProcessSharedLinkJob::class, 1);
        $this->assertEquals(1, Link::where('user_id', $user->id)->count());
    }

    public function test_quick_save_validates_required_url(): void
    {
        $user = User::create([
            'name' => 'Maya',
            'email' => 'maya@example.com',
        ]);

        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/links/quick-save', []);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
                'error_code' => 'VALIDATION_ERROR',
            ]);
    }

    public function test_quick_save_allows_specifying_collection_id_and_notes(): void
    {
        Queue::fake();

        $user = User::create([
            'name' => 'Niko',
            'email' => 'niko@example.com',
        ]);

        $collection = Collection::create([
            'user_id' => $user->id,
            'name' => 'Kuliner Pilihan',
            'slug' => 'kuliner-pilihan',
        ]);

        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/links/quick-save', [
                'url' => 'https://example.com/kuliner-bandung',
                'collection_id' => $collection->id,
                'user_notes' => 'Coba mie rica-rica',
            ]);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'collection_id' => $collection->id,
                    'user_notes' => 'Coba mie rica-rica',
                ],
            ]);

        $this->assertDatabaseHas('links', [
            'user_id' => $user->id,
            'collection_id' => $collection->id,
            'user_notes' => 'Coba mie rica-rica',
        ]);
    }
}
