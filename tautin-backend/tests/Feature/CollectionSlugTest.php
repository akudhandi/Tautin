<?php

namespace Tests\Feature;

use App\Models\Collection;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CollectionSlugTest extends TestCase
{
    use RefreshDatabase;

    public function test_free_user_cannot_set_a_custom_slug(): void
    {
        $user = User::create([
            'name' => 'Meri',
            'email' => 'meri@example.com',
            'plan_type' => 'free',
        ]);

        $collection = Collection::create([
            'user_id' => $user->id,
            'name' => 'Referensi Skripsi',
            'slug' => 'referensi-skripsi-'.$user->id,
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$user->createToken('test')->plainTextToken)
            ->patchJson('/api/v1/collections/'.$collection->id, [
                'slug' => 'skripsi-meri',
            ]);

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'error_code' => 'PRO_REQUIRED_FOR_CUSTOM_SLUG',
                'message' => 'Fitur kustomisasi tautan publik khusus untuk pengguna Tautin Pro.',
            ]);

        $this->assertSame('referensi-skripsi-'.$user->id, $collection->fresh()->slug);
    }

    public function test_free_user_can_update_other_fields_without_slug(): void
    {
        $user = User::create([
            'name' => 'Citra',
            'email' => 'citra@example.com',
            'plan_type' => 'free',
        ]);

        $collection = Collection::create([
            'user_id' => $user->id,
            'name' => 'Koleksi Citra',
            'slug' => 'koleksi-citra-'.$user->id,
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$user->createToken('test')->plainTextToken)
            ->patchJson('/api/v1/collections/'.$collection->id, [
                'name' => 'Koleksi Citra Baru',
            ]);

        $response->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertSame('Koleksi Citra Baru', $collection->fresh()->name);
    }

    public function test_pro_user_can_set_a_custom_public_slug(): void
    {
        $user = User::create([
            'name' => 'Rani Pro',
            'email' => 'rani.slug@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addMonth(),
        ]);

        $collection = Collection::create([
            'user_id' => $user->id,
            'name' => 'Tips Belanja',
            'slug' => 'tips-belanja-'.$user->id,
            'is_public' => true,
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$user->createToken('test')->plainTextToken)
            ->patchJson('/api/v1/collections/'.$collection->id, [
                'slug' => 'belanja-pintar-rani',
            ]);

        $response->assertStatus(200)
            ->assertJson(['success' => true]);

        $this->assertSame('belanja-pintar-rani', $collection->fresh()->slug);
    }

    public function test_custom_slug_must_be_unique_across_collections(): void
    {
        $user = User::create([
            'name' => 'Ubay Pro',
            'email' => 'ubay@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addMonth(),
        ]);

        Collection::create([
            'user_id' => $user->id,
            'name' => 'Milik Orang Lain',
            'slug' => 'resep-favorit-publik',
        ]);

        $collection = Collection::create([
            'user_id' => $user->id,
            'name' => 'Koleksi Ubay',
            'slug' => 'koleksi-ubay-'.$user->id,
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$user->createToken('test')->plainTextToken)
            ->patchJson('/api/v1/collections/'.$collection->id, [
                'slug' => 'resep-favorit-publik',
            ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false]);
    }

    public function test_custom_slug_must_pass_format_rules(): void
    {
        $user = User::create([
            'name' => 'Gita Pro',
            'email' => 'gita.slug@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addMonth(),
        ]);

        $collection = Collection::create([
            'user_id' => $user->id,
            'name' => 'Koleksi Gita',
            'slug' => 'koleksi-gita-'.$user->id,
        ]);

        // `alpha_dash` violation.
        $response = $this->withHeader('Authorization', 'Bearer '.$user->createToken('test')->plainTextToken)
            ->patchJson('/api/v1/collections/'.$collection->id, [
                'slug' => 'koleksi gita!!',
            ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false]);

        // max:100 violation (101 characters).
        $response = $this->withHeader('Authorization', 'Bearer '.$user->createToken('test')->plainTextToken)
            ->patchJson('/api/v1/collections/'.$collection->id, [
                'slug' => str_repeat('a', 101),
            ]);

        $response->assertStatus(422)
            ->assertJson(['success' => false]);

        $this->assertSame('koleksi-gita-'.$user->id, $collection->fresh()->slug);
    }
}
