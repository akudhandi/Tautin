<?php

namespace Tests\Feature;

use App\Models\Subscription;
use App\Models\User;
use App\Services\Billing\GooglePlayBillingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class VoidedPurchasesTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Isolate the static billing hooks between tests.
        GooglePlayBillingService::setMockVerifier(null);
        GooglePlayBillingService::setMockVoidedPurchases(null);
    }

    protected function tearDown(): void
    {
        GooglePlayBillingService::setMockVoidedPurchases(null);
        GooglePlayBillingService::setMockVerifier(null);

        parent::tearDown();
    }

    public function test_refunded_lifetime_purchase_is_revoked_by_sync_command(): void
    {
        $user = User::create([
            'name' => 'Oki Lifetime',
            'email' => 'oki.refund@example.com',
            'plan_type' => 'lifetime',
            'ai_quota_left' => 500,
        ]);

        $subscription = Subscription::create([
            'user_id' => $user->id,
            'product_id' => 'tautin_pro_lifetime',
            'purchase_token' => 'test_token_lifetime_refunded_001',
            'purchase_token_hash' => hash('sha256', 'test_token_lifetime_refunded_001'),
            'status' => 'active',
            'starts_at' => now()->subDays(30),
        ]);

        GooglePlayBillingService::setMockVoidedPurchases(
            fn (string $packageName): array => [$subscription->purchase_token]
        );

        $this->artisan('tautin:sync-subscriptions')
            ->expectsOutputToContain('dicabut karena refund Google Play')
            ->assertSuccessful();

        $subscription->refresh();
        $this->assertSame('refunded', $subscription->status);

        $user->refresh();
        $this->assertSame('free', $user->plan_type);
        $this->assertNull($user->plan_expires_at);
        // Refund revocation never tops the quota up: min(500, 10) = 10.
        $this->assertEquals(10, $user->ai_quota_left);
        $this->assertFalse($user->isPro());
    }

    public function test_refunded_pro_subscription_and_partial_quota_are_handled(): void
    {
        $user = User::create([
            'name' => 'Pram Refund',
            'email' => 'pram.refund@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addDays(20),
            'ai_quota_left' => 37, // Already partially consumed.
        ]);

        $subscription = Subscription::create([
            'user_id' => $user->id,
            'product_id' => 'tautin_pro_monthly',
            'purchase_token' => 'test_token_pro_refunded_002',
            'purchase_token_hash' => hash('sha256', 'test_token_pro_refunded_002'),
            'status' => 'active',
            'starts_at' => now()->subDays(10),
            'expires_at' => now()->addDays(20),
        ]);

        GooglePlayBillingService::setMockVoidedPurchases(
            fn (string $packageName): array => [$subscription->purchase_token]
        );

        $this->artisan('tautin:sync-subscriptions')->assertSuccessful();

        $subscription->refresh();
        $this->assertSame('refunded', $subscription->status);

        $user->refresh();
        $this->assertSame('free', $user->plan_type);
        // min(current quota, free quota) — no top-up to 10.
        $this->assertEquals(10, $user->ai_quota_left);
    }

    public function test_revoke_is_idempotent_for_already_refunded_rows(): void
    {
        $user = User::create([
            'name' => 'Wulan Refund',
            'email' => 'wulan.refund@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addDays(5),
            'ai_quota_left' => 44,
        ]);

        $subscription = Subscription::create([
            'user_id' => $user->id,
            'product_id' => 'tautin_pro_yearly',
            'purchase_token' => 'test_token_refunded_003',
            'purchase_token_hash' => hash('sha256', 'test_token_refunded_003'),
            'status' => 'refunded',
            'starts_at' => now()->subDays(100),
        ]);

        GooglePlayBillingService::setMockVoidedPurchases(
            fn (string $packageName): array => [$subscription->purchase_token]
        );

        $this->artisan('tautin:sync-subscriptions')->assertSuccessful();

        $subscription->refresh();
        $this->assertSame('refunded', $subscription->status);
    }

    public function test_users_without_voided_tokens_are_untouched(): void
    {
        $user = User::create([
            'name' => 'Bayu Aman',
            'email' => 'bayu.aman@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addDays(25),
            'ai_quota_left' => 490,
        ]);

        Subscription::create([
            'user_id' => $user->id,
            'product_id' => 'tautin_pro_monthly',
            'purchase_token' => 'test_token_aktif_004',
            'purchase_token_hash' => hash('sha256', 'test_token_aktif_004'),
            'status' => 'active',
            'starts_at' => now()->subDays(2),
            'expires_at' => now()->addDays(25),
        ]);

        // Nothing refunded at Google Play
        GooglePlayBillingService::setMockVoidedPurchases(
            fn (string $packageName): array => []
        );

        $this->artisan('tautin:sync-subscriptions')->assertSuccessful();

        $user->refresh();
        $this->assertSame('pro', $user->plan_type);
        $this->assertEquals(490, $user->ai_quota_left);
    }
}
