<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\BusinessLogicException;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\PublicCollectionResource;
use App\Http\Traits\ApiResponseTrait;
use App\Models\Collection;
use App\Models\Tag;
use App\Models\User;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PublicCollectionController extends Controller
{
    use ApiResponseTrait;

    /**
     * Show a public collection along with its completed links.
     */
    public function show(string $slug): JsonResponse
    {
        /** @var Collection|null $collection */
        $collection = Collection::where('slug', $slug)
            ->where('is_public', true)
            ->with([
                'user',
                'links' => fn (HasMany $q) => $q->where('status', 'completed')
                    ->with('tags')
                    ->orderBy('created_at', 'desc'),
            ])
            ->first();

        if (! $collection) {
            return $this->errorResponse(
                errorCode: 'COLLECTION_NOT_FOUND',
                message: 'Koleksi publik tidak ditemukan atau telah diubah menjadi privat.',
                httpCode: 404
            );
        }

        return $this->successResponse(
            data: new PublicCollectionResource($collection),
            message: 'Koleksi publik berhasil dimuat.'
        );
    }

    /**
     * Clone a public collection and all its links into current user's library.
     *
     * @throws BusinessLogicException
     */
    public function clone(Request $request, string $slug): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        /** @var Collection|null $sourceCollection */
        $sourceCollection = Collection::where('slug', $slug)
            ->where('is_public', true)
            ->with(['links.tags'])
            ->first();

        if (! $sourceCollection) {
            return $this->errorResponse(
                errorCode: 'COLLECTION_NOT_FOUND',
                message: 'Koleksi publik tidak ditemukan atau telah diubah menjadi privat.',
                httpCode: 404
            );
        }

        // Tier limit check for free users: only custom collections count, so a
        // free user can always keep their 5 default collections plus up to
        // `max_custom_collections` self-made folders.
        $maxCustomCollections = (int) config('tautin.free_plan.max_custom_collections', 3);
        if (! $user->isPro()
            && $user->collections()->where('is_default', false)->count() >= $maxCustomCollections
        ) {
            throw new BusinessLogicException(
                errorCode: 'COLLECTION_LIMIT_REACHED',
                message: 'Batas pembuatan koleksi kustom untuk akun Gratis ('.$maxCustomCollections.' koleksi tambahan) telah tercapai. Upgrade ke Tautin Pro untuk membuat koleksi tanpa batas!',
                httpStatus: 403
            );
        }

        $clonedCollection = DB::transaction(function () use ($user, $sourceCollection): Collection {
            $lastSort = (int) $user->collections()->max('sort_order');

            $newCollection = Collection::create([
                'user_id' => $user->id,
                'name' => $sourceCollection->name,
                'icon' => $sourceCollection->icon,
                'color' => $sourceCollection->color,
                'is_public' => false,
                'is_default' => false,
                'sort_order' => $lastSort + 1,
            ]);

            foreach ($sourceCollection->links as $sourceLink) {
                // If user doesn't already have this link, clone it
                $exists = $user->links()->where('url_hash', $sourceLink->url_hash)->exists();
                if (! $exists) {
                    $newLink = $user->links()->create([
                        'collection_id' => $newCollection->id,
                        'url' => $sourceLink->url,
                        'url_hash' => $sourceLink->url_hash,
                        'domain' => $sourceLink->domain,
                        'source_type' => $sourceLink->source_type,
                        'title' => $sourceLink->title,
                        'thumbnail_url' => $sourceLink->thumbnail_url,
                        'raw_description' => $sourceLink->raw_description,
                        'ai_summary' => $sourceLink->ai_summary,
                        'status' => 'completed',
                        'is_ai_processed' => $sourceLink->is_ai_processed,
                        'is_pinned' => false,
                        'is_read' => false,
                    ]);

                    // Clone tags
                    $tagIds = [];
                    foreach ($sourceLink->tags as $tag) {
                        $userTag = Tag::firstOrCreate([
                            'user_id' => $user->id,
                            'name' => $tag->name,
                        ]);
                        $tagIds[] = $userTag->id;
                    }

                    if (! empty($tagIds)) {
                        $newLink->tags()->sync($tagIds);
                    }
                }
            }

            return $newCollection;
        });

        return $this->successResponse(
            data: $clonedCollection->load(['links.tags'])->loadCount('links'),
            message: 'Koleksi berhasil disalin ke akunmu.',
            code: 201
        );
    }
}
