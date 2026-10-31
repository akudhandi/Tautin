<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Traits\ApiResponseTrait;
use App\Models\User;
use App\Services\Gamification\XpLevelService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GamificationController extends Controller
{
    use ApiResponseTrait;

    /**
     * Return the single source of truth for XP, level, streak and missions.
     *
     * The Flutter app only renders these numbers; it never computes XP itself
     * (PRD FR-GAME-01 AC-1).
     */
    public function summary(Request $request, XpLevelService $xpLevelService): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        return $this->successResponse(
            data: $xpLevelService->summary($user),
            message: 'Ringkasan gamifikasi berhasil dimuat.'
        );
    }
}
