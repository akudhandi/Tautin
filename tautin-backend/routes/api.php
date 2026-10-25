<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CollectionController;
use App\Http\Controllers\Api\V1\LinkController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    // Public Auth
    Route::post('/auth/google', [AuthController::class, 'google']);

    // Protected routes
    Route::middleware('auth:sanctum')->group(function (): void {
        // User profile & deletion
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::delete('/auth/account', [AuthController::class, 'deleteAccount']);

        // Links Ingestion
        Route::post('/links/quick-save', [LinkController::class, 'quickSave']);

        // Collections CRUD
        Route::get('/collections', [CollectionController::class, 'index']);
        Route::post('/collections', [CollectionController::class, 'store']);
        Route::patch('/collections/{id}', [CollectionController::class, 'update']);
        Route::delete('/collections/{id}', [CollectionController::class, 'destroy']);
    });
});
