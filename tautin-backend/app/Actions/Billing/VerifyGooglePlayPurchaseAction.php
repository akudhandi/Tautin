<?php

namespace App\Actions\Billing;

use App\Exceptions\BusinessLogicException;
use App\Models\Subscription;
use App\Models\User;
use App\Services\Billing\GooglePlayBillingService;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class VerifyGooglePlayPurchaseAction
{
    public function __construct(
        protected GooglePlayBillingService $billingService
    ) {}

    /**
     * Verify Google Play purchase token, prevent replay attacks, and activate user subscription.
     *
     * @return array{subscription: Subscription, user: User}
     *
     * @throws BusinessLogicException
     */
    public function execute(User $user, string $productId, string $purchaseToken, ?string $orderId = null): array
    {
        $validProducts = (array) config('tautin.google_play.products', [
            'tautin_pro_monthly',
            'tautin_pro_yearly',
            'tautin_pro_lifetime',
        ]);

        if (! in_array($productId, $validProducts, true)) {
            throw new BusinessLogicException(
                errorCode: 'INVALID_PRODUCT_ID',
                message: 'ID Produk Google Play tidak terdaftar di Tautin.',
                httpStatus: 422
            );
        }

        // Anti-replay check: prevent token re-use by a different user
        $tokenHash = hash('sha256', $purchaseToken);
        $existing = Subscription::where('purchase_token_hash', $tokenHash)->first();

        if ($existing && $existing->user_id !== $user->id) {
            throw new BusinessLogicException(
                errorCode: 'INVALID_PURCHASE_TOKEN',
                message: 'Token pembelian ini sudah digunakan oleh akun lain.',
                httpStatus: 422
            );
        }

        // Verify with Google Play Developer API
        if ($productId === 'tautin_pro_lifetime') {
            $verified = $this->billingService->verifyAndAcknowledgeProduct($productId, $purchaseToken);
        } else {
            $verified = $this->billingService->verifyAndAcknowledgeSubscription($productId, $purchaseToken);
        }

        return DB::transaction(function () use ($user, $productId, $purchaseToken, $tokenHash, $orderId, $verified) {
            $subscription = Subscription::updateOrCreate(
                ['purchase_token_hash' => $tokenHash],
                [
                    'user_id' => $user->id,
                    'product_id' => $productId,
                    'purchase_token' => $purchaseToken,
                    'order_id' => $verified['order_id'] ?? $orderId,
                    'status' => 'active',
                    'starts_at' => $verified['starts_at'],
                    'expires_at' => $verified['expires_at'],
                    'last_verified_at' => Carbon::now(),
                ]
            );

            if ($verified['is_lifetime']) {
                $user->update([
                    'plan_type' => 'lifetime',
                    'plan_expires_at' => null,
                ]);
            } else {
                $user->update([
                    'plan_type' => 'pro',
                    'plan_expires_at' => $verified['expires_at'],
                ]);
            }

            return [
                'subscription' => $subscription,
                'user' => $user->fresh(),
            ];
        });
    }
}
