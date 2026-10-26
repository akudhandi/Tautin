<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CollectionCustomLimitTest extends TestCase
{
    use RefreshDatabase;

    public function test_free_user_can_create_up_to_three_custom_collections(): void
    {
        $user = User::create([
            'name' => 'Zahra',
            'email' => 'zahra@example.com',
            'plan_type' => 'free',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        for ($i = 1; $i <= 10; $i++) {
            $response = $this->withHeader('Authorization', 'Bearer '.$token)
                ->postJson('/api/v1/collections', ['name' => 'Koleksi Kustom '.$i]);

            $response->assertStatus(201);
        }

        $this->assertEquals(10, $user->collections()->where('is_default', false)->count());
    }

    public function test_fourth_custom_collection_is_rejected_with_exact_message(): void
    {
        $user = User::create([
            'name' => 'Laras',
            'email' => 'laras@example.com',
            'plan_type' => 'free',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        for ($i = 1; $i <= 10; $i++) {
            $this->withHeader('Authorization', 'Bearer '.$token)
                ->postJson('/api/v1/collections', ['name' => 'Koleksi Kustom '.$i])
                ->assertStatus(201);
        }

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/collections', ['name' => 'Koleksi Kustom 11']);

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'error_code' => 'COLLECTION_LIMIT_REACHED',
                'message' => 'Batas pembuatan koleksi kustom untuk akun Gratis (10 koleksi tambahan) telah tercapai. Upgrade ke Tautin Pro untuk membuat koleksi tanpa batas!',
            ]);
    }

    public function test_seeded_default_collections_do_not_count_toward_the_custom_limit(): void
    {
        // Registering through the real auth flow seeds 5 default collections
        // (is_default = true) right away.
        $response = $this->postJson('/api/v1/auth/google', [
            'id_token' => 'test-token:google_sub_302:mega@example.com',
        ]);
        $response->assertStatus(201);

        $token = (string) $response->json('data.token');
        $user = User::where('email', 'mega@example.com')->firstOrFail();

        $this->assertEquals(5, $user->collections()->where('is_default', true)->count());

        // All 10 custom slots remain available next to the 5 seeded defaults.
        for ($i = 1; $i <= 10; $i++) {
            $this->withHeader('Authorization', 'Bearer '.$token)
                ->postJson('/api/v1/collections', ['name' => 'Koleksi Mega '.$i])
                ->assertStatus(201);
        }

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/collections', ['name' => 'Koleksi Mega 11']);

        $response->assertStatus(403)
            ->assertJson(['error_code' => 'COLLECTION_LIMIT_REACHED']);

        $user->refresh();
        $this->assertEquals(15, $user->collections()->count());
    }

    public function test_pro_user_can_create_custom_collections_without_limit(): void
    {
        $user = User::create([
            'name' => 'Nadia Pro',
            'email' => 'nadia@example.com',
            'plan_type' => 'pro',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        for ($i = 1; $i <= 4; $i++) {
            $response = $this->withHeader('Authorization', 'Bearer '.$token)
                ->postJson('/api/v1/collections', ['name' => 'Koleksi Pro '.$i]);

            $response->assertStatus(201);
        }

        $this->assertEquals(4, $user->collections()->where('is_default', false)->count());
    }

    public function test_cloning_a_public_collection_respects_the_custom_limit(): void
    {
        $owner = User::create([
            'name' => 'Owner Publik',
            'email' => 'owner.publik@example.com',
            'plan_type' => 'pro',
        ]);

        $owner->collections()->create([
            'name' => 'Wisata Hemat',
            'slug' => 'wisata-hemat',
            'is_public' => true,
        ]);

        $user = User::create([
            'name' => 'Cloe Free',
            'email' => 'cloe@example.com',
            'plan_type' => 'free',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        for ($i = 1; $i <= 10; $i++) {
            $this->withHeader('Authorization', 'Bearer '.$token)
                ->postJson('/api/v1/collections', ['name' => 'Koleksi Cloe '.$i])
                ->assertStatus(201);
        }

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/public/collections/wisata-hemat/clone');

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'error_code' => 'COLLECTION_LIMIT_REACHED',
                'message' => 'Batas pembuatan koleksi kustom untuk akun Gratis (10 koleksi tambahan) telah tercapai. Upgrade ke Tautin Pro untuk membuat koleksi tanpa batas!',
            ]);
    }
}
