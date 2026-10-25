<?php

namespace Tests\Feature;

use App\Models\Link;
use App\Models\Subscription;
use App\Models\User;
use App\Services\Billing\GooglePlayBillingService;
use App\Services\Notification\FcmNotificationService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SchedulerCommandsTest extends TestCase
{
    use RefreshDatabase;

    public function test_dispatch_link_reminders_sends_notification_and_updates_flag(): void
    {
        $dispatchedNotifications = [];
        FcmNotificationService::setMockHandler(function ($token, $title, $body, $data) use (&$dispatchedNotifications) {
            $dispatchedNotifications[] = compact('token', 'title', 'body', 'data');

            return true;
        });

        $user = User::create([
            'name' => 'Rudy Remind',
            'email' => 'rudy@example.com',
            'fcm_token' => 'fcm_rudy_device_token',
        ]);

        // Due reminder
        $dueLink = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/due',
            'url_hash' => hash('sha256', 'https://example.com/due'),
            'domain' => 'example.com',
            'title' => 'Resep Kue Cubit Lumer',
            'remind_at' => Carbon::now()->subMinute(),
            'reminder_sent' => false,
        ]);

        // Future reminder (not due)
        $futureLink = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/future',
            'url_hash' => hash('sha256', 'https://example.com/future'),
            'domain' => 'example.com',
            'title' => 'Resep Martabak Manis',
            'remind_at' => Carbon::now()->addHour(),
            'reminder_sent' => false,
        ]);

        $this->artisan('tautin:dispatch-reminders')
            ->assertSuccessful();

        $dueLink->refresh();
        $futureLink->refresh();

        $this->assertTrue($dueLink->reminder_sent);
        $this->assertFalse($futureLink->reminder_sent);

        $this->assertCount(1, $dispatchedNotifications);
        $this->assertEquals('fcm_rudy_device_token', $dispatchedNotifications[0]['token']);
        $this->assertStringContainsString('Resep Kue Cubit Lumer', $dispatchedNotifications[0]['title']);

        FcmNotificationService::setMockHandler(null);
    }

    public function test_sync_expired_subscriptions_downgrades_expired_user_to_free(): void
    {
        $user = User::create([
            'name' => 'Sinta Sub',
            'email' => 'sinta@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => Carbon::now()->subMinutes(30),
            'ai_quota_left' => 0,
        ]);

        $sub = Subscription::create([
            'user_id' => $user->id,
            'product_id' => 'tautin_pro_monthly',
            'purchase_token' => 'expired_google_play_token_123',
            'purchase_token_hash' => hash('sha256', 'expired_google_play_token_123'),
            'status' => 'active',
            'starts_at' => Carbon::now()->subMonth(),
            'expires_at' => Carbon::now()->subMinutes(30),
        ]);

        // Mock Google Play returning expired state
        GooglePlayBillingService::setMockVerifier(function ($productId, $token, $type) {
            throw new \Exception('Subscription is expired');
        });

        $this->artisan('tautin:sync-subscriptions')
            ->assertSuccessful();

        $user->refresh();
        $sub->refresh();

        $this->assertEquals('free', $user->plan_type);
        $this->assertEquals(10, $user->ai_quota_left);
        $this->assertEquals('expired', $sub->status);

        GooglePlayBillingService::setMockVerifier(null);
    }

    public function test_send_weekly_digest_sends_to_users_with_at_least_three_unread_links(): void
    {
        $digestsSent = [];
        FcmNotificationService::setMockHandler(function ($token, $title, $body, $data) use (&$digestsSent) {
            $digestsSent[] = compact('token', 'title', 'body', 'data');

            return true;
        });

        // User A has 3 unread links and FCM token -> receives digest
        $userA = User::create([
            'name' => 'Tono Digest',
            'email' => 'tono@example.com',
            'fcm_token' => 'fcm_token_tono',
        ]);
        for ($i = 1; $i <= 3; $i++) {
            Link::create([
                'user_id' => $userA->id,
                'url' => 'https://example.com/a'.$i,
                'url_hash' => hash('sha256', 'https://example.com/a'.$i),
                'domain' => 'example.com',
                'title' => 'Link Tono '.$i,
                'is_read' => false,
            ]);
        }

        // User B has only 1 unread link -> does NOT receive digest
        $userB = User::create([
            'name' => 'Umar Single',
            'email' => 'umar@example.com',
            'fcm_token' => 'fcm_token_umar',
        ]);
        Link::create([
            'user_id' => $userB->id,
            'url' => 'https://example.com/b1',
            'url_hash' => hash('sha256', 'https://example.com/b1'),
            'domain' => 'example.com',
            'title' => 'Link Umar 1',
            'is_read' => false,
        ]);

        $this->artisan('tautin:send-weekly-digest')
            ->assertSuccessful();

        $this->assertCount(1, $digestsSent);
        $this->assertEquals('fcm_token_tono', $digestsSent[0]['token']);
        $this->assertEquals('weekly_digest', $digestsSent[0]['data']['type']);

        FcmNotificationService::setMockHandler(null);
    }

    public function test_reset_monthly_ai_quota_restores_free_user_quota_to_ten(): void
    {
        $freeUser1 = User::create([
            'name' => 'Vera Free 1',
            'email' => 'vera1@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 0, // Kuota habis
        ]);

        $freeUser2 = User::create([
            'name' => 'Vera Free 2',
            'email' => 'vera2@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 4, // Kuota sisa 4
        ]);

        $proUser = User::create([
            'name' => 'Wawan Pro',
            'email' => 'wawan@example.com',
            'plan_type' => 'pro',
            'ai_quota_left' => 999,
        ]);

        $this->artisan('tautin:reset-monthly-quota')
            ->assertSuccessful();

        $freeUser1->refresh();
        $freeUser2->refresh();
        $proUser->refresh();

        $this->assertEquals(10, $freeUser1->ai_quota_left);
        $this->assertEquals(10, $freeUser2->ai_quota_left);
        $this->assertEquals(999, $proUser->ai_quota_left);
    }
}
