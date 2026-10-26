<?php

return [
    'free_plan' => [
        // 5 default (is_default = true) collections are seeded on signup and are
        // free-of-charge. The limit below only counts user-created custom
        // collections (is_default = false).
        'max_custom_collections' => 10,
        'max_public_collections' => 1,
        'monthly_ai_quota' => 10,
    ],
    'pro_plan' => [
        'fair_use_monthly_ai_quota' => 500,
    ],
    'google_play' => [
        'package_name' => 'id.my.sengganglabs.tautin',
        'products' => [
            'tautin_pro_monthly',
            'tautin_pro_yearly',
            'tautin_pro_lifetime',
        ],
        'service_account_path' => env('GOOGLE_PLAY_SERVICE_ACCOUNT_PATH', storage_path('app/google-play-service-account.json')),
        // Shared secret required by the Pub/Sub RTDN push endpoint
        // (query param `?secret=` or `X-RTDN-Secret` header).
        'rtdn_secret' => env('GOOGLE_PLAY_RTDN_SECRET'),
    ],
    'gemini' => [
        'model' => 'gemini-2.5-flash',
        'api_key' => env('GEMINI_API_KEY'),
    ],
];
