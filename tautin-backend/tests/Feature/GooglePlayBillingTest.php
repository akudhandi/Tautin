<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class GooglePlayBillingTest extends TestCase
{
    use RefreshDatabase;

    public function test_verify_lifetime_purchase_activates_lifetime_plan(): void
    {
        $user = User::create([
            'name' => 'Oki Lifetime',
            'email' => 'oki@example.com',
            'plan_type' => 'free',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/billing/verify-purchase', [
                'product_id' => 'tautin_pro_lifetime',
                'purchase_token' => 'test_token_lifetime_12345',
                'order_id' => 'GPA.1234-5678-9012-34567',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'user' => [
                        'plan_type' => 'lifetime',
                        'plan_expires_at' => null,
                    ],
                    'subscription' => [
                        'product_id' => 'tautin_pro_lifetime',
                        'status' => 'active',
                    ],
                ],
            ]);

        $user->refresh();
        $this->assertEquals('lifetime', $user->plan_type);
        $this->assertNull($user->plan_expires_at);
        $this->assertTrue($user->isPro());

        $this->assertDatabaseHas('subscriptions', [
            'user_id' => $user->id,
            'product_id' => 'tautin_pro_lifetime',
            'status' => 'active',
        ]);
    }

    public function test_verify_subscription_activates_pro_plan_with_expiry(): void
    {
        $user = User::create([
            'name' => 'Pram Sub',
            'email' => 'pram@example.com',
            'plan_type' => 'free',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/billing/verify-purchase', [
                'product_id' => 'tautin_pro_yearly',
                'purchase_token' => 'test_token_yearly_67890',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'user' => [
                        'plan_type' => 'pro',
                    ],
                    'subscription' => [
                        'product_id' => 'tautin_pro_yearly',
                        'status' => 'active',
                    ],
                ],
            ]);

        $user->refresh();
        $this->assertEquals('pro', $user->plan_type);
        $this->assertNotNull($user->plan_expires_at);
        $this->assertTrue($user->plan_expires_at->isFuture());
        $this->assertTrue($user->isPro());
    }

    public function test_anti_replay_protects_against_token_theft_by_another_user(): void
    {
        $legitUser = User::create([
            'name' => 'Legit User',
            'email' => 'legit@example.com',
            'plan_type' => 'free',
        ]);
        $legitToken = $legitUser->createToken('test')->plainTextToken;

        $sharedPurchaseToken = 'test_token_shared_secret_999';

        // 1. Legit user verifies first
        $this->withHeader('Authorization', 'Bearer '.$legitToken)
            ->postJson('/api/v1/billing/verify-purchase', [
                'product_id' => 'tautin_pro_lifetime',
                'purchase_token' => $sharedPurchaseToken,
            ])->assertStatus(200);

        // 2. Attacker user tries to reuse the exact same purchase_token
        $attacker = User::create([
            'name' => 'Attacker',
            'email' => 'attacker@example.com',
            'plan_type' => 'free',
        ]);
        $attackerToken = $attacker->createToken('test')->plainTextToken;

        $this->flushHeaders();
        $this->app['auth']->forgetGuards();

        $response = $this->withHeader('Authorization', 'Bearer '.$attackerToken)
            ->postJson('/api/v1/billing/verify-purchase', [
                'product_id' => 'tautin_pro_lifetime',
                'purchase_token' => $sharedPurchaseToken,
            ]);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
                'error_code' => 'INVALID_PURCHASE_TOKEN',
            ]);

        $attacker->refresh();
        $this->assertEquals('free', $attacker->plan_type);
    }

    public function test_restore_endpoint_recovers_active_subscription(): void
    {
        $user = User::create([
            'name' => 'Qori Restore',
            'email' => 'qori.restore@example.com',
            'plan_type' => 'free',
        ]);
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/v1/billing/restore', [
                'purchases' => [
                    [
                        'product_id' => 'tautin_pro_monthly',
                        'purchase_token' => 'test_token_restore_111',
                    ],
                ],
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'restored_count' => 1,
                    'user' => [
                        'plan_type' => 'pro',
                    ],
                ],
            ]);

        $user->refresh();
        $this->assertEquals('pro', $user->plan_type);
        $this->assertTrue($user->isPro());
    }
}
