<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\Auth\AuthenticateGoogleUserAction;
use App\Actions\Auth\DeleteUserAccountAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\DeleteAccountRequest;
use App\Http\Requests\Api\V1\GoogleAuthRequest;
use App\Http\Traits\ApiResponseTrait;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    use ApiResponseTrait;

    /**
     * Authenticate or register a user with Google ID token.
     */
    public function google(GoogleAuthRequest $request, AuthenticateGoogleUserAction $action): JsonResponse
    {
        $result = $action->execute($request->validated());

        $collections = $result['user']->collections()
            ->withCount('links')
            ->orderBy('sort_order', 'asc')
            ->get();

        return $this->successResponse(
            data: [
                'user' => $result['user'],
                'token' => $result['token'],
                'collections' => $collections,
                'is_new_user' => $result['is_new_user'],
            ],
            message: $result['is_new_user'] ? 'Pendaftaran berhasil.' : 'Login berhasil.',
            code: $result['is_new_user'] ? 201 : 200,
            meta: [
                'ai_quota_left' => $result['user']->ai_quota_left,
                'plan_type' => $result['user']->plan_type,
            ]
        );
    }

    /**
     * Get the authenticated user profile and subscription metadata.
     */
    public function me(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user()->load(['collections' => function ($query) {
            $query->orderBy('sort_order', 'asc');
        }]);

        return $this->successResponse(
            data: $user,
            message: 'Profil pengguna berhasil dimuat.',
            meta: [
                'ai_quota_left' => $user->ai_quota_left,
                'plan_type' => $user->plan_type,
                'is_pro' => $user->isPro(),
                'plan_expires_at' => $user->plan_expires_at?->toIso8601String(),
            ]
        );
    }

    /**
     * Permanently delete user account and all related data.
     */
    public function deleteAccount(DeleteAccountRequest $request, DeleteUserAccountAction $action): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        $action->execute($user);

        return $this->successResponse(
            data: null,
            message: 'Akun dan seluruh data Anda telah berhasil dihapus permanen.'
        );
    }
}
