<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\Collections\CreateCollectionAction;
use App\Actions\Collections\UpdateCollectionAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\StoreCollectionRequest;
use App\Http\Requests\Api\V1\UpdateCollectionRequest;
use App\Http\Traits\ApiResponseTrait;
use App\Models\Collection;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CollectionController extends Controller
{
    use ApiResponseTrait;

    /**
     * Display a listing of the user's collections.
     */
    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $collections = $user->collections()
            ->withCount('links')
            ->orderBy('sort_order', 'asc')
            ->get();

        return $this->successResponse(
            data: $collections,
            message: 'Daftar koleksi berhasil dimuat.'
        );
    }

    /**
     * Store a newly created collection.
     */
    public function store(StoreCollectionRequest $request, CreateCollectionAction $action): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $collection = $action->execute($user, $request->validated());

        return $this->successResponse(
            data: $collection->loadCount('links'),
            message: 'Koleksi baru berhasil dibuat.',
            code: 201
        );
    }

    /**
     * Update the specified collection.
     */
    public function update(UpdateCollectionRequest $request, int $id, UpdateCollectionAction $action): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        /** @var Collection $collection */
        $collection = $user->collections()->findOrFail($id);

        $updated = $action->execute($user, $collection, $request->validated());

        return $this->successResponse(
            data: $updated->loadCount('links'),
            message: 'Koleksi berhasil diperbarui.'
        );
    }

    /**
     * Remove the specified collection from storage.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        /** @var Collection $collection */
        $collection = $user->collections()->findOrFail($id);

        $collection->delete();

        return $this->successResponse(
            data: null,
            message: 'Koleksi berhasil dihapus.'
        );
    }
}
