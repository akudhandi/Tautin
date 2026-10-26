<?php

namespace Tests\Feature;

use App\Models\Collection;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_google_auth_registers_new_user_and_seeds_5_default_collections(): void
    {
        $response = $this->postJson('/api/v1/auth/google', [
            'id_token' => 'test-token:google_sub_101:budi@example.com',
            'fcm_token' => 'sample_fcm_token_123',
        ]);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_new_user' => true,
                    'user' => [
                        'email' => 'budi@example.com',
                        'plan_type' => 'free',
                        'ai_quota_left' => 10,
                    ],
                ],
                'meta' => [
                    'ai_quota_left' => 10,
                    'plan_type' => 'free',
                ],
            ])
            ->assertJsonCount(5, 'data.collections');

        $this->assertDatabaseHas('users', [
            'email' => 'budi@example.com',
            'google_id' => 'google_sub_101',
            'plan_type' => 'free',
            'ai_quota_left' => 10,
            'fcm_token' => 'sample_fcm_token_123',
        ]);

        $user = User::where('email', 'budi@example.com')->first();
        $this->assertNotNull($user);
        $this->assertCount(5, $user->collections);

        $collectionNames = $user->collections->pluck('name')->all();
        $this->assertContains('Belanja & Wishlist', $collectionNames);
        $this->assertContains('Resep & Kuliner', $collectionNames);
        $this->assertContains('Tontonan & Hiburan', $collectionNames);
        $this->assertContains('Belajar & Referensi', $collectionNames);
        $this->assertContains('Tempat & Jalan-jalan', $collectionNames);
    }

    public function test_google_auth_logs_in_existing_user_without_duplicating_collections(): void
    {
        // First login (registers user)
        $this->postJson('/api/v1/auth/google', [
            'id_token' => 'test-token:google_sub_102:siti@example.com',
        ])->assertStatus(201);

        // Second login (existing user)
        $response = $this->postJson('/api/v1/auth/google', [
            'id_token' => 'test-token:google_sub_102:siti@example.com',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'is_new_user' => false,
                ],
            ]);

        $user = User::where('email', 'siti@example.com')->first();
        $this->assertNotNull($user);
        $this->assertCount(5, $user->collections);
    }

    public function test_delete_account_fails_without_confirmation_field(): void
    {
        $user = User::create([
            'name' => 'Faro',
            'email' => 'faro@example.com',
            'google_id' => 'google_sub_106',
        ]);

        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->deleteJson('/api/v1/auth/account', []);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
                'error_code' => 'VALIDATION_ERROR',
            ]);

        $this->assertDatabaseHas('users', ['id' => $user->id]);
    }

    public function test_get_current_user_profile(): void
    {
        $user = User::create([
            'name' => 'Ahmad',
            'email' => 'ahmad@example.com',
            'google_id' => 'google_sub_103',
            'plan_type' => 'free',
            'ai_quota_left' => 8,
        ]);

        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->getJson('/api/v1/auth/me');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $user->id,
                    'email' => 'ahmad@example.com',
                ],
                'meta' => [
                    'ai_quota_left' => 8,
                    'plan_type' => 'free',
                    'is_pro' => false,
                ],
            ]);
    }

    public function test_delete_account_permanently(): void
    {
        $user = User::create([
            'name' => 'Doni',
            'email' => 'doni@example.com',
            'google_id' => 'google_sub_104',
            'plan_type' => 'free',
        ]);

        Collection::create([
            'user_id' => $user->id,
            'name' => 'Koleksi Doni',
            'slug' => 'koleksi-doni',
        ]);

        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->deleteJson('/api/v1/auth/account', [
                'confirmation' => 'HAPUS',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ]);

        $this->assertDatabaseMissing('users', ['id' => $user->id]);
        $this->assertDatabaseMissing('collections', ['user_id' => $user->id]);
    }

    public function test_delete_account_fails_without_proper_confirmation(): void
    {
        $user = User::create([
            'name' => 'Eka',
            'email' => 'eka@example.com',
            'google_id' => 'google_sub_105',
        ]);

        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->deleteJson('/api/v1/auth/account', [
                'confirmation' => 'salah',
            ]);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
                'error_code' => 'VALIDATION_ERROR',
            ]);
    }
}
