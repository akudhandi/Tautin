<?php

namespace Tests\Feature;

use App\Models\Subscription;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Config;
use Tests\TestCase;

class RtdnWebhookTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Config::set('tautin.google_play.rtdn_secret', 'rtdn_shared_secret_2026');
    }

    /**
     * Build a Pub/Sub push envelope with base64-encoded JSON data.
     *
     * @param  array<string, mixed>  $notification
     * @return array<string, array<string, string>>
     */
    protected function pubsubEnvelope(array $notification): array
    {
        return [
            'message' => [
                'data' => base64_encode((string) json_encode($notification)),
                'messageId' => 'msg-'.uniqid(),
            ],
        ];
    }

    public function test_missing_secret_is_unauthorized(): void
    {
        $response = $this->postJson('/api/v1/webhooks/google-play-rtdn', $this->pubsubEnvelope([
            'testNotification' => ['version' => '1.0'],
        ]));

        $response->assertStatus(401)
            ->assertJson([
                'success' => false,
                'error_code' => 'UNAUTHORIZED_WEBHOOK',
            ]);
    }

    public function test_wrong_secret_is_unauthorized(): void
    {
        $response = $this->postJson('/api/v1/webhooks/google-play-rtdn?secret= Salah', $this->pubsubEnvelope([
            'testNotification' => ['version' => '1.0'],
        ]));

        $response->assertStatus(401)
            ->assertJson(['error_code' => 'UNAUTHORIZED_WEBHOOK']);
    }

    public function test_valid_secret_via_header_is_accepted(): void
    {
        $response = $this->withHeader('X-RTDN-Secret', 'rtdn_shared_secret_2026')
            ->postJson('/api/v1/webhooks/google-play-rtdn', $this->pubsubEnvelope([
                'testNotification' => ['version' => '1.0'],
            ]));

        $response->assertStatus(202)
            ->assertJson(['success' => true]);
    }

    public function test_voided_purchase_notification_refunds_subscription_and_downgrades_user(): void
    {
        $user = User::create([
            'name' => 'Nara Refund',
            'email' => 'nara.rtdn@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addDays(10),
            'ai_quota_left' => 240,
        ]);

        $subscription = Subscription::create([
            'user_id' => $user->id,
            'product_id' => 'tautin_pro_monthly',
            'purchase_token' => 'rtdn_voided_token_001',
            'purchase_token_hash' => hash('sha256', 'rtdn_voided_token_001'),
            'status' => 'active',
            'starts_at' => now()->subDays(2),
        ]);

        $response = $this->postJson(
            '/api/v1/webhooks/google-play-rtdn?secret=rtdn_shared_secret_2026',
            $this->pubsubEnvelope([
                'voidedPurchaseNotification' => [
                    'purchaseToken' => $subscription->purchase_token,
                    'productId' => 'tautin_pro_monthly',
                ],
            ])
        );

        $response->assertStatus(202)
            ->assertJson(['success' => true]);

        $subscription->refresh();
        $this->assertSame('refunded', $subscription->status);

        $user->refresh();
        $this->assertSame('free', $user->plan_type);
        $this->assertNull($user->plan_expires_at);
        $this->assertEquals(10, $user->ai_quota_left);
    }

    public function test_subscription_revoked_event_type_12_marks_refund(): void
    {
        $user = User::create([
            'name' => 'Dira Revoked',
            'email' => 'dira.rtdn@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addDays(3),
            'ai_quota_left' => 90,
        ]);

        $subscription = Subscription::create([
            'user_id' => $user->id,
            'product_id' => 'tautin_pro_yearly',
            'purchase_token' => 'rtdn_revoked_token_002',
            'purchase_token_hash' => hash('sha256', 'rtdn_revoked_token_002'),
            'status' => 'active',
            'starts_at' => now()->subDays(1),
        ]);

        $response = $this->postJson(
            '/api/v1/webhooks/google-play-rtdn?secret=rtdn_shared_secret_2026',
            $this->pubsubEnvelope([
                'subscriptionNotification' => [
                    'version' => '1.0',
                    'subscriptionNotificationType' => 12,
                    'purchaseToken' => $subscription->purchase_token,
                    'subscriptionId' => 'tautin_pro_yearly',
                ],
            ])
        );

        $response->assertStatus(202)
            ->assertJson(['success' => true]);

        $subscription->refresh();
        $this->assertSame('refunded', $subscription->status);

        $user->refresh();
        $this->assertSame('free', $user->plan_type);
    }

    public function test_renewal_event_type_2_restores_pro_status(): void
    {
        $user = User::create([
            'name' => 'Elsa Renewed',
            'email' => 'elsa.rtdn@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 10,
        ]);

        $subscription = Subscription::create([
            'user_id' => $user->id,
            'product_id' => 'tautin_pro_monthly',
            'purchase_token' => 'test_token_rtdn_renewal_003',
            'purchase_token_hash' => hash('sha256', 'test_token_rtdn_renewal_003'),
            'status' => 'expired',
            'starts_at' => now()->subMonths(2),
            'expires_at' => now()->subDays(2),
        ]);

        $response = $this->postJson(
            '/api/v1/webhooks/google-play-rtdn?secret=rtdn_shared_secret_2026',
            $this->pubsubEnvelope([
                'subscriptionNotification' => [
                    'version' => '1.0',
                    'subscriptionNotificationType' => 2,
                    'purchaseToken' => $subscription->purchase_token,
                    'subscriptionId' => 'tautin_pro_monthly',
                ],
            ])
        );

        $response->assertStatus(202)
            ->assertJson(['success' => true]);

        $subscription->refresh();
        $this->assertSame('active', $subscription->status);

        $user->refresh();
        $this->assertSame('pro', $user->plan_type);
        $this->assertTrue($user->plan_expires_at->isFuture());
        $this->assertEquals(500, $user->ai_quota_left);
    }

    public function test_payload_without_data_is_acked_to_avoid_pubsub_retries(): void
    {
        $response = $this->postJson(
            '/api/v1/webhooks/google-play-rtdn?secret=rtdn_shared_secret_2026',
            []
        );

        $response->assertStatus(202)
            ->assertJson(['success' => true]);
    }
}
