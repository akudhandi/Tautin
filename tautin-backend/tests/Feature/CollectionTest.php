<?php

namespace Tests\Feature;

use App\Actions\Auth\SeedDefaultCollectionsAction;
use App\Models\Collection;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CollectionTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_list_their_collections_with_links_count(): void
    {
        $user = User::create([
            'name' => 'Fahri',
            'email' => 'fahri@example.com',
            'google_id' => 'google_sub_201',
            'plan_type' => 'free',
        ]);

        Collection::create([
            'user_id' => $user->id,
            'name' => 'Koleksi 1',
            'slug' => 'koleksi-1',
            'sort_order' => 1,
        ]);

        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/collections');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    [
                        'name' => 'Koleksi 1',
                        'links_count' => 0,
                    ],
                ],
            ]);
    }

    public function test_free_user_gets_three_custom_slots_beside_seeded_defaults(): void
    {
        $user = User::create([
            'name' => 'Gina',
            'email' => 'gina@example.com',
            'google_id' => 'google_sub_202',
            'plan_type' => 'free',
        ]);

        // Signup seeds 5 default collections (is_default = true); they never
        // count toward the 10 custom-collection slots.
        app(SeedDefaultCollectionsAction::class)->execute($user);
        $this->assertEquals(5, $user->collections()->where('is_default', true)->count());

        $token = $user->createToken('test')->plainTextToken;

        // The first 10 custom collections succeed...
        for ($i = 1; $i <= 10; $i++) {
            $this->withHeader('Authorization', 'Bearer '.$token)
                ->postJson('/api/v1/collections', [
                    'name' => 'Koleksi Kustom '.$i,
                ])
                ->assertStatus(201);
        }

        // ...and the 11th custom collection is rejected.
        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/collections', [
                'name' => 'Koleksi Kustom 11',
                'icon' => 'folder',
                'color' => '#3B82F6',
            ]);

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'error_code' => 'COLLECTION_LIMIT_REACHED',
            ]);

        // 5 seeded defaults + 10 custom collections.
        $this->assertEquals(15, $user->collections()->count());
    }

    public function test_pro_user_can_create_more_than_five_collections(): void
    {
        $user = User::create([
            'name' => 'Hadi',
            'email' => 'hadi@example.com',
            'google_id' => 'google_sub_203',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addMonth(),
        ]);

        app(SeedDefaultCollectionsAction::class)->execute($user);
        $this->assertEquals(5, $user->collections()->count());

        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/collections', [
                'name' => 'Koleksi Keenam Pro',
                'icon' => 'star',
                'color' => '#F59E0B',
            ]);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'name' => 'Koleksi Keenam Pro',
                ],
            ]);

        $this->assertEquals(6, $user->collections()->count());
    }

    public function test_free_user_cannot_activate_more_than_one_public_collection(): void
    {
        $user = User::create([
            'name' => 'Indah',
            'email' => 'indah@example.com',
            'google_id' => 'google_sub_204',
            'plan_type' => 'free',
        ]);

        $c1 = Collection::create([
            'user_id' => $user->id,
            'name' => 'Koleksi Publik 1',
            'slug' => 'koleksi-publik-1',
            'is_public' => true,
            'sort_order' => 1,
        ]);

        $c2 = Collection::create([
            'user_id' => $user->id,
            'name' => 'Koleksi Privat 2',
            'slug' => 'koleksi-privat-2',
            'is_public' => false,
            'sort_order' => 2,
        ]);

        $token = $user->createToken('test')->plainTextToken;

        // Try to update second collection to public
        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->patchJson('/api/v1/collections/'.$c2->id, [
                'is_public' => true,
            ]);

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'error_code' => 'PUBLIC_COLLECTION_LIMIT_REACHED',
            ]);

        $this->assertFalse($c2->fresh()->is_public);
    }

    public function test_user_can_update_and_delete_collection(): void
    {
        $user = User::create([
            'name' => 'Joko',
            'email' => 'joko@example.com',
            'google_id' => 'google_sub_205',
            'plan_type' => 'free',
        ]);

        $c = Collection::create([
            'user_id' => $user->id,
            'name' => 'Koleksi Lama',
            'slug' => 'koleksi-lama',
            'color' => '#000000',
        ]);

        $token = $user->createToken('test')->plainTextToken;

        // Update
        $this->withHeader('Authorization', 'Bearer '.$token)
            ->patchJson('/api/v1/collections/'.$c->id, [
                'name' => 'Koleksi Baru',
                'color' => '#FFFFFF',
            ])
            ->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'name' => 'Koleksi Baru',
                    'color' => '#FFFFFF',
                ],
            ]);

        // Delete
        $this->withHeader('Authorization', 'Bearer '.$token)
            ->deleteJson('/api/v1/collections/'.$c->id)
            ->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);

        $this->assertDatabaseMissing('collections', ['id' => $c->id]);
    }
}
