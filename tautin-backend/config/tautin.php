<?php

return [
    'free_plan' => [
        'max_collections' => 5,
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
    ],
    'gemini' => [
        'model' => 'gemini-2.5-flash',
        'api_key' => env('GEMINI_API_KEY'),
    ],
];
