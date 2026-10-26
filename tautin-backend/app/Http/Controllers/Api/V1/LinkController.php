<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\Links\QuickSaveLinkAction;
use App\Actions\Links\RegenerateAiAction;
use App\Actions\Links\UpdateLinkAction;
use App\Exceptions\BusinessLogicException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\QuickSaveLinkRequest;
use App\Http\Requests\Api\V1\UpdateLinkRequest;
use App\Http\Traits\ApiResponseTrait;
use App\Models\Link;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class LinkController extends Controller
{
    use ApiResponseTrait;

    /**
     * Display a listing of user links with search, filters, and pagination.
     */
    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $query = $user->links();

        // 1. Optional Search Query (Full-Text & Contextual Fallback)
        if ($request->filled('search')) {
            $search = trim((string) $request->input('search'));
            $driver = DB::connection()->getDriverName();

            if ($driver === 'mysql') {
                $booleanTerm = preg_replace('/[+\-><()~*\"@]+/', ' ', $search);
                $words = array_filter(explode(' ', trim((string) $booleanTerm)));
                $againstTerm = implode(' ', array_map(fn ($w) => "+{$w}*", $words));

                $query->where(function (Builder $q) use ($againstTerm, $search): void {
                    $q->whereRaw('MATCH(title, ai_summary, user_notes) AGAINST(? IN BOOLEAN MODE)', [$againstTerm ?: $search])
                        ->orWhere('domain', 'like', "%{$search}%")
                        ->orWhere('title', 'like', "%{$search}%")
                        ->orWhereHas('tags', fn (Builder $tq) => $tq->where('name', 'like', "%{$search}%"));
                });
            } else {
                // SQLite in-memory testing fallback
                $query->where(function (Builder $q) use ($search): void {
                    $term = "%{$search}%";
                    $q->where('title', 'like', $term)
                        ->orWhere('ai_summary', 'like', $term)
                        ->orWhere('user_notes', 'like', $term)
                        ->orWhere('domain', 'like', $term)
                        ->orWhereHas('tags', fn (Builder $tq) => $tq->where('name', 'like', $term));
                });
            }
        }

        // 2. Collection filter (`?collection_id=unassigned` returns links with
        //    no folder, shown on the "📦 Tanpa Koleksi" tab in Flutter)
        if ($request->filled('collection_id')) {
            $collectionFilter = (string) $request->input('collection_id');

            if ($collectionFilter === 'unassigned') {
                $query->whereNull('collection_id');
            } elseif (is_numeric($collectionFilter)) {
                $query->where('collection_id', (int) $collectionFilter);
            }
        }

        // 3. Source Type filter
        if ($request->filled('source_type')) {
            $query->where('source_type', (string) $request->input('source_type'));
        }

        // 4. Read status filter
        if ($request->has('is_read')) {
            $query->where('is_read', $request->boolean('is_read'));
        }

        // 5. Tag filter
        if ($request->filled('tag')) {
            $tag = (string) $request->input('tag');
            $query->whereHas('tags', fn (Builder $tq) => $tq->where('name', $tag));
        }

        // Default order: is_pinned DESC, updated_at DESC
        $query->orderBy('is_pinned', 'desc')
            ->orderBy('updated_at', 'desc');

        $perPage = min(max($request->integer('per_page', 20), 1), 100);
        $links = $query->with(['collection', 'tags'])->paginate($perPage);

        return $this->successResponse(
            data: $links,
            message: 'Daftar tautan berhasil dimuat.'
        );
    }

    /**
     * Resurface up to 3 random unread links older than 3 days.
     *
     * Per PRD `FR-REM-01`: the carousel only appears when the user owns at
     * least 3 eligible links; otherwise an empty list is returned so the
     * Flutter home screen hides the section entirely.
     */
    public function resurface(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $query = $user->links()
            ->where('is_read', false)
            ->where('created_at', '<=', now()->subDays(3));

        if ((clone $query)->count() < 3) {
            return $this->successResponse(
                data: [],
                message: 'Daftar tautan untuk dibaca ulang berhasil dimuat.'
            );
        }

        $resurfaced = $query->inRandomOrder()
            ->limit(3)
            ->with(['collection', 'tags'])
            ->get();

        return $this->successResponse(
            data: $resurfaced,
            message: 'Daftar tautan untuk dibaca ulang berhasil dimuat.'
        );
    }

    /**
     * Quickly ingest a shared link from Android Share Sheet (< 300ms).
     */
    public function quickSave(QuickSaveLinkRequest $request, QuickSaveLinkAction $action): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $result = $action->execute($user, $request->validated());

        return $this->successResponse(
            data: $result['link'],
            message: $result['is_duplicate']
                ? 'Tautan ini sudah ada di koleksimu, dinaikkan ke paling atas!'
                : 'Tautan berhasil disimpan.',
            code: $result['is_duplicate'] ? 200 : 201,
            meta: [
                'is_duplicate' => $result['is_duplicate'],
                'ai_quota_left' => $user->ai_quota_left,
                'plan_type' => $user->plan_type,
            ]
        );
    }

    /**
     * Regenerate the AI summary, folder, and tags of a link (Pro/Lifetime only).
     *
     * @throws BusinessLogicException
     */
    public function regenerateAi(Request $request, int $id, RegenerateAiAction $regenerateAction): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        /** @var Link $link */
        $link = $regenerateAction->execute($user, $id);

        return $this->successResponse(
            data: $link,
            message: 'Ringkasan AI akan dibuat ulang. Cek kembali beberapa saat lagi.',
            meta: [
                'ai_quota_left' => $user->ai_quota_left,
                'plan_type' => $user->plan_type,
            ]
        );
    }

    /**
     * Display the specified link.
     */
    public function show(Request $request, int $id): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        /** @var Link $link */
        $link = $user->links()->with(['collection', 'tags'])->findOrFail($id);

        return $this->successResponse(
            data: $link,
            message: 'Detail tautan berhasil dimuat.'
        );
    }

    /**
     * Update the specified link in storage.
     */
    public function update(UpdateLinkRequest $request, int $id, UpdateLinkAction $action): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        /** @var Link $link */
        $link = $user->links()->findOrFail($id);

        $updated = $action->execute($user, $link, $request->validated());

        return $this->successResponse(
            data: $updated,
            message: 'Tautan berhasil diperbarui.'
        );
    }

    /**
     * Remove the specified link from storage.
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        /** @var Link $link */
        $link = $user->links()->findOrFail($id);

        $link->delete();

        return $this->successResponse(
            data: null,
            message: 'Tautan berhasil dihapus.'
        );
    }
}
