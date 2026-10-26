<?php

namespace App\Actions\Collections;

use App\Exceptions\BusinessLogicException;
use App\Models\Collection;
use App\Models\User;

class CreateCollectionAction
{
    /**
     * Create a new collection for user respecting tier limits.
     *
     * The 5 default collections (`is_default = true`) seeded on signup are
     * free. This limit only counts user-created custom collections
     * (`is_default = false`), so a free user can end up with at most
     * 5 default + 10 custom collections.
     *
     * @param  array{name: string, icon?: ?string, color?: ?string, is_public?: ?bool}  $data
     */
    public function execute(User $user, array $data): Collection
    {
        $maxCustomCollections = (int) config('tautin.free_plan.max_custom_collections', 10);

        if (! $user->isPro()
            && $user->collections()->where('is_default', false)->count() >= $maxCustomCollections
        ) {
            throw new BusinessLogicException(
                errorCode: 'COLLECTION_LIMIT_REACHED',
                message: 'Batas pembuatan koleksi kustom untuk akun Gratis ('.$maxCustomCollections.' koleksi tambahan) telah tercapai. Upgrade ke Tautin Pro untuk membuat koleksi tanpa batas!',
                httpStatus: 403
            );
        }

        $isPublic = (bool) ($data['is_public'] ?? false);
        if ($isPublic && ! $user->isPro()) {
            $maxPublic = (int) config('tautin.free_plan.max_public_collections', 1);
            if ($user->collections()->where('is_public', true)->count() >= $maxPublic) {
                throw new BusinessLogicException(
                    errorCode: 'PUBLIC_COLLECTION_LIMIT_REACHED',
                    message: 'Pengguna gratis hanya dapat membagikan '.$maxPublic.' koleksi publik. Upgrade ke Tautin Pro untuk membagikan koleksi tanpa batas.',
                    httpStatus: 403
                );
            }
        }

        $lastSortOrder = (int) $user->collections()->max('sort_order');

        return Collection::create([
            'user_id' => $user->id,
            'name' => $data['name'],
            'icon' => $data['icon'] ?? 'folder',
            'color' => $data['color'] ?? '#4F46E5',
            'is_public' => $isPublic,
            'is_default' => false,
            'sort_order' => $lastSortOrder + 1,
        ]);
    }
}
