<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\Links\QuickSaveLinkAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\QuickSaveLinkRequest;
use App\Http\Traits\ApiResponseTrait;
use App\Models\User;
use Illuminate\Http\JsonResponse;

class LinkController extends Controller
{
    use ApiResponseTrait;

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
}
