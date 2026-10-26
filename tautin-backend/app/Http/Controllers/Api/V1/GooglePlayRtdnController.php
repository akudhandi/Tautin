<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Traits\ApiResponseTrait;
use App\Models\Subscription;
use App\Models\User;
use App\Services\Billing\GooglePlayBillingService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class GooglePlayRtdnController extends Controller
{
    use ApiResponseTrait;

    // Google Play subscriptionNotification subtype codes:
    // 1 = RECOVERED, 2 = RENEWED, 3 = CANCELED, 12 = REVOKED, 13 = EXPIRED.
    private const RENEWAL_TYPES = [1, 2];

    private const CANCELLATION_TYPES = [3, 12, 13];

    /**
     * Handle a Google Cloud Pub/Sub push message carrying a
     * Real-Time Developer Notification (RTDN) for Google Play.
     *
     * Expected payload shape:
     * { "message": { "data": "<base64 of JSON>", "messageId": "...", "publishTime": "..." } }
     *
     * The inner JSON contains either `subscriptionNotification`
     * (with `subscriptionNotificationType`, `purchaseToken`, ...) or
     * `voidedPurchaseNotification` / `testNotification`.
     */
    public function handle(Request $request): JsonResponse
    {
        $secret = (string) config('tautin.google_play.rtdn_secret');
        $provided = (string) ($request->query('secret') ?? $request->header('X-RTDN-Secret', ''));

        if ($secret === '' || ! hash_equals($secret, $provided)) {
            return response()->json([
                'success' => false,
                'error_code' => 'UNAUTHORIZED_WEBHOOK',
                'message' => 'Secret webhook RTDN tidak valid.',
            ], 401);
        }

        $message = $request->input('message.data');
        if (empty($message)) {
            // Pub/Sub requires a 2xx acknowledgement even for unhandled events,
            // otherwise the same push is retried forever.
            return $this->successResponse(
                data: null,
                message: 'Notifikasi RTDN diabaikan tanpa data.',
                code: 202
            );
        }

        $decoded = json_decode((string) base64_decode((string) $message, true), true);
        if (! is_array($decoded)) {
            return $this->successResponse(
                data: null,
                message: 'Payload RTDN tidak dapat diparse.',
                code: 202
            );
        }

        $purchaseToken = null;

        $subscriptionNotification = $decoded['subscriptionNotification'] ?? null;
        if (is_array($subscriptionNotification)) {
            $purchaseToken = $subscriptionNotification['purchaseToken'] ?? null;
            $type = (int) ($subscriptionNotification['subscriptionNotificationType'] ?? 0);

            if (in_array($type, self::RENEWAL_TYPES, true)) {
                $this->refreshSubscription($purchaseToken);
            } elseif (in_array($type, self::CANCELLATION_TYPES, true)) {
                $this->refundSubscription($purchaseToken);
            }
        }

        $voidedNotification = $decoded['voidedPurchaseNotification'] ?? null;
        if (is_array($voidedNotification)) {
            $this->refundSubscription($voidedNotification['purchaseToken'] ?? null);
        }

        if (isset($decoded['testNotification'])) {
            Log::info('Google Play RTDN test notification received', $decoded['testNotification']);
        }

        return $this->successResponse(
            data: null,
            message: 'Notifikasi RTDN berhasil diproses.',
            code: 202
        );
    }

    /**
     * Re-verify a subscription after a renewal/recovery event and restore the
     * user's Pro status.
     */
    protected function refreshSubscription(mixed $purchaseToken): void
    {
        if (! is_string($purchaseToken) || $purchaseToken === '') {
            return;
        }

        /** @var Subscription|null $subscription */
        $subscription = Subscription::where('purchase_token', $purchaseToken)->first();

        if (! $subscription) {
            return;
        }

        $billingService = app(GooglePlayBillingService::class);
        $now = Carbon::now();

        try {
            $verified = $billingService->verifyAndAcknowledgeSubscription(
                $subscription->product_id,
                $subscription->purchase_token
            );

            $subscription->update([
                'status' => 'active',
                'expires_at' => $verified['expires_at'],
                'last_verified_at' => $now,
            ]);

            /** @var User|null $user */
            $user = $subscription->user;
            if ($user) {
                $user->update([
                    'plan_type' => 'pro',
                    'plan_expires_at' => $verified['expires_at'],
                    'ai_quota_left' => (int) config('tautin.pro_plan.fair_use_monthly_ai_quota', 500),
                ]);
            }
        } catch (\Throwable $e) {
            Log::warning('RTDN subscription refresh failed', [
                'subscription_id' => $subscription->id,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Mark the subscription refunded and downgrade the user to free.
     */
    protected function refundSubscription(mixed $purchaseToken): void
    {
        if (! is_string($purchaseToken) || $purchaseToken === '') {
            return;
        }

        /** @var Subscription|null $subscription */
        $subscription = Subscription::where('purchase_token', $purchaseToken)->first();

        if (! $subscription || $subscription->status === 'refunded') {
            return;
        }

        $subscription->update(['status' => 'refunded']);

        /** @var User|null $user */
        $user = $subscription->user;
        if ($user && $user->plan_type !== 'free') {
            $freeQuota = (int) config('tautin.free_plan.monthly_ai_quota', 10);

            $user->update([
                'plan_type' => 'free',
                'plan_expires_at' => null,
                'ai_quota_left' => min((int) $user->ai_quota_left, $freeQuota),
            ]);
        }
    }
}
