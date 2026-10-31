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
    'gamification' => [
        // Every streak/mission period is computed in WIB (PRD FR-GAME-03).
        'timezone' => 'Asia/Jakarta',
        // XP awarded per action. The client never computes XP (PRD FR-GAME-01).
        'xp' => [
            'save' => 10,
            'read' => 5,
            'pin' => 3,
            'mission' => 20,
        ],
        // A user levels up every `level_step` XP: level = floor(xp / step) + 1.
        'level_step' => 100,
        // Title per level (PRD FR-GAME-02); levels past the end keep the last title.
        'titles' => [
            1 => 'Pemula Tautan',
            2 => 'Penyimpan Rajin',
            3 => 'Pemungut Tautan',
            4 => 'Kurator Cilik',
            5 => 'Master Tautan',
        ],
        // Streak shield: how many missed days may be forgiven per calendar week.
        'streak_shields_per_week' => [
            'free' => 1,
            'pro' => 3,
        ],
        // Daily/weekly missions shown on Beranda & Profil.
        'missions' => [
            [
                'key' => 'daily_save_3',
                'period_type' => 'daily',
                'target' => 3,
                'label' => 'Simpan 3 tautan',
                'track' => 'save',
            ],
            [
                'key' => 'daily_read_1',
                'period_type' => 'daily',
                'target' => 1,
                'label' => 'Baca 1 tautan',
                'track' => 'read',
            ],
            [
                'key' => 'weekly_curate_10',
                'period_type' => 'weekly',
                'target' => 10,
                'label' => 'Simpan 10 tautan minggu ini',
                'track' => 'save',
            ],
        ],
    ],
];
