<?php

namespace App\Actions\Collections;

use App\Exceptions\BusinessLogicException;
use App\Models\Collection;
use App\Models\User;

class UpdateCollectionAction
{
    /**
     * Update an existing collection respecting public collection limits and
     * Pro-only custom slug settings.
     *
     * @param  array{name?: string, icon?: ?string, color?: ?string, is_public?: bool, sort_order?: int, slug?: string}  $data
     */
    public function execute(User $user, Collection $collection, array $data): Collection
    {
        if (isset($data['slug']) && is_string($data['slug']) && $data['slug'] !== $collection->slug) {
            if (! $user->isPro()) {
                throw new BusinessLogicException(
                    errorCode: 'PRO_REQUIRED_FOR_CUSTOM_SLUG',
                    message: 'Fitur kustomisasi tautan publik khusus untuk pengguna Tautin Pro.',
                    httpStatus: 403
                );
            }

            $slugTaken = Collection::where('slug', $data['slug'])
                ->where('id', '!=', $collection->id)
                ->exists();

            if ($slugTaken) {
                throw new BusinessLogicException(
                    errorCode: 'COLLECTION_SLUG_TAKEN',
                    message: 'Slug "'.$data['slug'].'" sudah dipakai koleksi lain. Pilih slug lain.',
                    httpStatus: 422
                );
            }
        }

        if (isset($data['is_public']) && $data['is_public'] && ! $collection->is_public && ! $user->isPro()) {
            $maxPublic = (int) config('tautin.free_plan.max_public_collections', 1);
            $currentPublicCount = $user->collections()
                ->where('is_public', true)
                ->where('id', '!=', $collection->id)
                ->count();

            if ($currentPublicCount >= $maxPublic) {
                throw new BusinessLogicException(
                    errorCode: 'PUBLIC_COLLECTION_LIMIT_REACHED',
                    message: 'Pengguna gratis hanya dapat membagikan '.$maxPublic.' koleksi publik. Upgrade ke Tautin Pro untuk membagikan koleksi tanpa batas.',
                    httpStatus: 403
                );
            }
        }

        $collection->update($data);

        return $collection->fresh();
    }
}
