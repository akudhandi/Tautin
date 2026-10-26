<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BillingController;
use App\Http\Controllers\Api\V1\CollectionController;
use App\Http\Controllers\Api\V1\GooglePlayRtdnController;
use App\Http\Controllers\Api\V1\LinkController;
use App\Http\Controllers\Api\V1\PublicCollectionController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    // Google Cloud Pub/Sub Real-Time Developer Notifications (RTDN)
    Route::post('/webhooks/google-play-rtdn', [GooglePlayRtdnController::class, 'handle']);

    // Public Auth & Public Collections
    Route::post('/auth/google', [AuthController::class, 'google']);
    Route::get('/public/collections/{slug}', [PublicCollectionController::class, 'show']);

    // Protected routes
    Route::middleware('auth:sanctum')->group(function (): void {
        // User profile & deletion
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::delete('/auth/account', [AuthController::class, 'deleteAccount']);

        // Links Management & Ingestion
        Route::get('/links', [LinkController::class, 'index']);
        Route::get('/links/resurface', [LinkController::class, 'resurface']);
        Route::post('/links/quick-save', [LinkController::class, 'quickSave']);
        Route::post('/links/{id}/regenerate-ai', [LinkController::class, 'regenerateAi']);
        Route::get('/links/{id}', [LinkController::class, 'show']);
        Route::patch('/links/{id}', [LinkController::class, 'update']);
        Route::delete('/links/{id}', [LinkController::class, 'destroy']);

        // Collections CRUD & Public Cloning
        Route::get('/collections', [CollectionController::class, 'index']);
        Route::post('/collections', [CollectionController::class, 'store']);
        Route::patch('/collections/{id}', [CollectionController::class, 'update']);
        Route::delete('/collections/{id}', [CollectionController::class, 'destroy']);
        Route::post('/public/collections/{slug}/clone', [PublicCollectionController::class, 'clone']);

        // Google Play Billing
        Route::post('/billing/verify-purchase', [BillingController::class, 'verifyPurchase']);
        Route::post('/billing/restore', [BillingController::class, 'restore']);
    });
});
