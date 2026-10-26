<?php

namespace App\Actions\Auth;

use App\Models\Collection;
use App\Models\User;

class SeedDefaultCollectionsAction
{
    /**
     * The 5 default starter collections for new users.
     *
     * @var list<array{name: string, icon: string, color: string, is_default?: bool}>
     */
    public const DEFAULT_COLLECTIONS = [
        [
            'name' => 'Belanja & Wishlist',
            'icon' => 'shopping_bag',
            'color' => '#EC4899',
            'is_default' => true,
        ],
        [
            'name' => 'Resep & Kuliner',
            'icon' => 'restaurant',
            'color' => '#F59E0B',
            'is_default' => true,
        ],
        [
            'name' => 'Tontonan & Hiburan',
            'icon' => 'play_circle',
            'color' => '#EF4444',
            'is_default' => true,
        ],
        [
            'name' => 'Belajar & Referensi',
            'icon' => 'school',
            'color' => '#3B82F6',
            'is_default' => true,
        ],
        [
            'name' => 'Tempat & Jalan-jalan',
            'icon' => 'place',
            'color' => '#10B981',
            'is_default' => true,
        ],
    ];

    /**
     * Seed default collections for the given user.
     *
     * @return \Illuminate\Database\Eloquent\Collection<int, Collection>
     */
    public function execute(User $user): \Illuminate\Database\Eloquent\Collection
    {
        $created = [];

        foreach (self::DEFAULT_COLLECTIONS as $index => $item) {
            $created[] = Collection::create([
                'user_id' => $user->id,
                'name' => $item['name'],
                'icon' => $item['icon'],
                'color' => $item['color'],
                'is_default' => $item['is_default'] ?? false,
                'is_public' => false,
                'sort_order' => $index + 1,
            ]);
        }

        return new \Illuminate\Database\Eloquent\Collection($created);
    }
}
