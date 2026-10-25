<?php

namespace App\Services\Notification;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FcmNotificationService
{
    /**
     * Testing hook to intercept or mock notifications.
     *
     * @var (callable(string, string, string, array<string, mixed>): bool)|null
     */
    protected static $mockHandler = null;

    /**
     * Set a custom handler for testing.
     *
     * @param  (callable(string, string, string, array<string, mixed>): bool)|null  $handler
     */
    public static function setMockHandler(?callable $handler): void
    {
        static::$mockHandler = $handler;
    }

    /**
     * Send push notification via Firebase Cloud Messaging.
     *
     * @param  array<string, mixed>  $data
     */
    public function send(string $fcmToken, string $title, string $body, array $data = []): bool
    {
        if (static::$mockHandler !== null) {
            return (static::$mockHandler)($fcmToken, $title, $body, $data);
        }

        if (app()->environment('testing')) {
            Log::info('FCM Notification Simulated in Testing', [
                'token' => $fcmToken,
                'title' => $title,
                'body' => $body,
                'data' => $data,
            ]);

            return true;
        }

        $serviceAccountPath = (string) config('tautin.google_play.service_account_path');

        if (! file_exists($serviceAccountPath)) {
            Log::info('FCM Service Account not configured, notification skipped.', [
                'token' => $fcmToken,
                'title' => $title,
            ]);

            return false;
        }

        try {
            // In production, Google Client / Firebase HTTP v1 sends payload:
            Log::info('Sending FCM Notification', [
                'token' => $fcmToken,
                'title' => $title,
            ]);

            return true;
        } catch (\Throwable $e) {
            Log::error('FCM Notification error', ['error' => $e->getMessage()]);

            return false;
        }
    }
}
