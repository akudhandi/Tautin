<?php

namespace App\Services\Billing;

use App\Exceptions\BusinessLogicException;
use Carbon\Carbon;
use Google\Client as GoogleClient;
use Google\Service\AndroidPublisher;
use Google\Service\AndroidPublisher\ProductPurchasesAcknowledgeRequest;
use Google\Service\AndroidPublisher\SubscriptionPurchasesAcknowledgeRequest;
use Illuminate\Support\Facades\Log;

class GooglePlayBillingService
{
    /**
     * Testing hook to mock verification without reaching Google APIs.
     *
     * @var (callable(string, string, string): array<string, mixed>)|null
     */
    protected static $mockVerifier = null;

    /**
     * Set a custom verifier callback for testing.
     *
     * @param  (callable(string, string, string): array<string, mixed>)|null  $verifier
     */
    public static function setMockVerifier(?callable $verifier): void
    {
        static::$mockVerifier = $verifier;
    }

    /**
     * Get the configured package name.
     */
    public function getPackageName(): string
    {
        return (string) config('tautin.google_play.package_name', 'id.my.sengganglabs.tautin');
    }

    /**
     * Verify and acknowledge a one-time in-app product purchase (e.g. tautin_pro_lifetime).
     *
     * @return array{order_id: ?string, status: string, starts_at: Carbon, expires_at: null, is_lifetime: bool}
     *
     * @throws BusinessLogicException
     */
    public function verifyAndAcknowledgeProduct(string $productId, string $purchaseToken): array
    {
        if (static::$mockVerifier !== null) {
            /** @var array{order_id: ?string, status: string, starts_at: Carbon, expires_at: null, is_lifetime: bool} */
            return (static::$mockVerifier)($productId, $purchaseToken, 'product');
        }

        // Automatic fallback for testing environment with test tokens
        if (app()->environment('testing') && str_starts_with($purchaseToken, 'test_')) {
            return [
                'order_id' => 'GPA.TEST-'.strtoupper(substr(hash('sha256', $purchaseToken), 0, 16)),
                'status' => 'active',
                'starts_at' => Carbon::now(),
                'expires_at' => null,
                'is_lifetime' => true,
            ];
        }

        $packageName = $this->getPackageName();
        $publisher = $this->getAndroidPublisher();

        try {
            $purchase = $publisher->purchases_products->get($packageName, $productId, $purchaseToken);

            // purchaseState: 0 = Purchased, 1 = Canceled, 2 = Pending
            if ($purchase->getPurchaseState() !== 0) {
                throw new BusinessLogicException(
                    errorCode: 'INVALID_PURCHASE_STATE',
                    message: 'Status pembelian Google Play tidak valid atau belum selesai dibayar.',
                    httpStatus: 422
                );
            }

            // Acknowledge within 3 days to prevent automatic Google Play refund
            if ($purchase->getAcknowledgementState() === 0) {
                $ackRequest = new ProductPurchasesAcknowledgeRequest;
                $publisher->purchases_products->acknowledge($packageName, $productId, $purchaseToken, $ackRequest);
            }

            return [
                'order_id' => $purchase->getOrderId(),
                'status' => 'active',
                'starts_at' => Carbon::now(),
                'expires_at' => null,
                'is_lifetime' => true,
            ];
        } catch (BusinessLogicException $e) {
            throw $e;
        } catch (\Throwable $e) {
            Log::error('Google Play Product Verification Failed', [
                'product_id' => $productId,
                'error' => $e->getMessage(),
            ]);

            throw new BusinessLogicException(
                errorCode: 'INVALID_PURCHASE_TOKEN',
                message: 'Verifikasi pembelian Google Play gagal: '.$e->getMessage(),
                httpStatus: 422
            );
        }
    }

    /**
     * Verify and acknowledge a recurring subscription purchase (e.g. tautin_pro_monthly, tautin_pro_yearly).
     *
     * @return array{order_id: ?string, status: string, starts_at: Carbon, expires_at: Carbon, is_lifetime: bool}
     *
     * @throws BusinessLogicException
     */
    public function verifyAndAcknowledgeSubscription(string $productId, string $purchaseToken): array
    {
        if (static::$mockVerifier !== null) {
            /** @var array{order_id: ?string, status: string, starts_at: Carbon, expires_at: Carbon, is_lifetime: bool} */
            return (static::$mockVerifier)($productId, $purchaseToken, 'subscription');
        }

        // Automatic fallback for testing environment with test tokens
        if (app()->environment('testing') && str_starts_with($purchaseToken, 'test_')) {
            $months = str_contains($productId, 'yearly') ? 12 : 1;

            return [
                'order_id' => 'GPA.TEST-'.strtoupper(substr(hash('sha256', $purchaseToken), 0, 16)),
                'status' => 'active',
                'starts_at' => Carbon::now(),
                'expires_at' => Carbon::now()->addMonths($months),
                'is_lifetime' => false,
            ];
        }

        $packageName = $this->getPackageName();
        $publisher = $this->getAndroidPublisher();

        try {
            $subscription = $publisher->purchases_subscriptionsv2->get($packageName, $purchaseToken);
            $state = $subscription->getSubscriptionState();

            $validStates = ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'];
            if (! in_array($state, $validStates, true)) {
                throw new BusinessLogicException(
                    errorCode: 'SUBSCRIPTION_NOT_ACTIVE',
                    message: 'Status langganan Google Play tidak aktif ('.$state.').',
                    httpStatus: 422
                );
            }

            $lineItems = $subscription->getLineItems();
            $expiryTime = null;
            if (! empty($lineItems) && isset($lineItems[0])) {
                $expiryTime = $lineItems[0]->getExpiryTime();
            }

            if (empty($expiryTime)) {
                throw new BusinessLogicException(
                    errorCode: 'INVALID_SUBSCRIPTION_EXPIRY',
                    message: 'Waktu kedaluwarsa langganan tidak ditemukan dari Google Play.',
                    httpStatus: 422
                );
            }

            $expiresAt = Carbon::parse($expiryTime);

            // Acknowledge if pending
            if ($subscription->getAcknowledgementState() === 'ACKNOWLEDGEMENT_STATE_PENDING') {
                $ackRequest = new SubscriptionPurchasesAcknowledgeRequest;
                $publisher->purchases_subscriptions->acknowledge($packageName, $productId, $purchaseToken, $ackRequest);
            }

            return [
                'order_id' => $subscription->getLatestOrderId(),
                'status' => 'active',
                'starts_at' => Carbon::now(),
                'expires_at' => $expiresAt,
                'is_lifetime' => false,
            ];
        } catch (BusinessLogicException $e) {
            throw $e;
        } catch (\Throwable $e) {
            Log::error('Google Play Subscription Verification Failed', [
                'product_id' => $productId,
                'error' => $e->getMessage(),
            ]);

            throw new BusinessLogicException(
                errorCode: 'INVALID_PURCHASE_TOKEN',
                message: 'Verifikasi langganan Google Play gagal: '.$e->getMessage(),
                httpStatus: 422
            );
        }
    }

    /**
     * Build authenticated Google AndroidPublisher client.
     */
    protected function getAndroidPublisher(): AndroidPublisher
    {
        $serviceAccountPath = (string) config('tautin.google_play.service_account_path');

        if (! file_exists($serviceAccountPath)) {
            throw new BusinessLogicException(
                errorCode: 'GOOGLE_CREDENTIALS_MISSING',
                message: 'Kredensial Service Account Google Play tidak ditemukan di server.',
                httpStatus: 500
            );
        }

        $client = new GoogleClient;
        $client->setAuthConfig($serviceAccountPath);
        $client->addScope(AndroidPublisher::ANDROIDPUBLISHER);

        return new AndroidPublisher($client);
    }
}
