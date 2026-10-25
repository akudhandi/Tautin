<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\Billing\VerifyGooglePlayPurchaseAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\RestorePurchasesRequest;
use App\Http\Requests\Api\V1\VerifyPurchaseRequest;
use App\Http\Traits\ApiResponseTrait;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;

class BillingController extends Controller
{
    use ApiResponseTrait;

    /**
     * Verify a Google Play purchase receipt and upgrade user plan.
     */
    public function verifyPurchase(
        VerifyPurchaseRequest $request,
        VerifyGooglePlayPurchaseAction $action
    ): JsonResponse {
        /** @var User $user */
        $user = $request->user();

        $productId = (string) $request->input('product_id');
        $purchaseToken = (string) $request->input('purchase_token');
        $orderId = $request->input('order_id') ? (string) $request->input('order_id') : null;

        $result = $action->execute($user, $productId, $purchaseToken, $orderId);

        return $this->successResponse(
            data: [
                'user' => $result['user'],
                'subscription' => $result['subscription'],
            ],
            message: 'Pembelian berhasil diverifikasi. Akunmu kini aktif di paket '.strtoupper($result['user']->plan_type).'!'
        );
    }

    /**
     * Restore purchases when switching devices or reinstalling app.
     */
    public function restore(
        RestorePurchasesRequest $request,
        VerifyGooglePlayPurchaseAction $action
    ): JsonResponse {
        /** @var User $user */
        $user = $request->user();

        /** @var list<array{product_id: string, purchase_token: string, order_id?: ?string}> $purchases */
        $purchases = $request->input('purchases');
        $restoredCount = 0;
        $lastSubscription = null;

        foreach ($purchases as $item) {
            try {
                $result = $action->execute(
                    $user,
                    $item['product_id'],
                    $item['purchase_token'],
                    $item['order_id'] ?? null
                );
                $restoredCount++;
                $lastSubscription = $result['subscription'];
            } catch (\Throwable $e) {
                Log::info('Failed to restore individual purchase token', [
                    'user_id' => $user->id,
                    'product_id' => $item['product_id'],
                    'error' => $e->getMessage(),
                ]);
            }
        }

        $freshUser = $user->fresh();

        return $this->successResponse(
            data: [
                'restored_count' => $restoredCount,
                'user' => $freshUser,
                'last_subscription' => $lastSubscription,
            ],
            message: $restoredCount > 0
                ? 'Status langganan berhasil dipulihkan.'
                : 'Tidak ada pembelian aktif yang dapat dipulihkan.'
        );
    }
}
