<?php

namespace App\Actions\Auth;

use App\Exceptions\BusinessLogicException;
use App\Models\User;
use Google\Client as GoogleClient;
use Illuminate\Support\Facades\Log;

class AuthenticateGoogleUserAction
{
    public function __construct(
        protected SeedDefaultCollectionsAction $seedCollectionsAction
    ) {}

    /**
     * Authenticate or register a user via Google ID Token.
     *
     * @param  array{id_token: string, fcm_token?: ?string, name?: ?string, email?: ?string, google_id?: ?string, avatar?: ?string}  $data
     * @return array{user: User, token: string, is_new_user: bool}
     */
    public function execute(array $data): array
    {
        $payload = $this->verifyGoogleToken($data['id_token']);

        $googleId = $payload['sub'] ?? ($data['google_id'] ?? null);
        $email = $payload['email'] ?? ($data['email'] ?? null);
        $name = $payload['name'] ?? ($data['name'] ?? 'Pengguna Tautin');
        $avatar = $payload['picture'] ?? ($data['avatar'] ?? null);

        if (! $email) {
            throw new BusinessLogicException('INVALID_AUTH_TOKEN', 'Email tidak ditemukan dari akun Google.', 401);
        }

        $user = User::where('email', $email)->orWhere('google_id', $googleId)->first();
        $isNewUser = false;

        if (! $user) {
            $isNewUser = true;
            $user = User::create([
                'name' => $name,
                'email' => $email,
                'google_id' => $googleId,
                'avatar' => $avatar,
                'plan_type' => 'free',
                'ai_quota_left' => config('tautin.free_plan.monthly_ai_quota', 10),
                'fcm_token' => $data['fcm_token'] ?? null,
            ]);

            $this->seedCollectionsAction->execute($user);
        } else {
            $updates = [];
            if (! empty($data['fcm_token'])) {
                $updates['fcm_token'] = $data['fcm_token'];
            }
            if (! empty($avatar) && $user->avatar !== $avatar) {
                $updates['avatar'] = $avatar;
            }
            if (! empty($googleId) && empty($user->google_id)) {
                $updates['google_id'] = $googleId;
            }
            if (! empty($updates)) {
                $user->update($updates);
            }
        }

        $token = $user->createToken('tautin-mobile')->plainTextToken;

        return [
            'user' => $user->load('collections'),
            'token' => $token,
            'is_new_user' => $isNewUser,
        ];
    }

    /**
     * Verify the Google ID Token.
     *
     * @return array<string, mixed>
     */
    protected function verifyGoogleToken(string $idToken): array
    {
        if (app()->environment('local', 'testing') && str_starts_with($idToken, 'test-token:')) {
            $parts = explode(':', $idToken, 3);

            return [
                'sub' => $parts[1] ?? 'test_google_id_123',
                'email' => $parts[2] ?? 'test@example.com',
                'name' => 'Test User',
                'picture' => 'https://example.com/avatar.png',
            ];
        }

        try {
            $client = new GoogleClient;
            $payload = $client->verifyIdToken($idToken);

            if (! $payload) {
                throw new BusinessLogicException('INVALID_AUTH_TOKEN', 'Token Google tidak valid atau telah kedaluwarsa.', 401);
            }

            return $payload;
        } catch (BusinessLogicException $e) {
            throw $e;
        } catch (\Throwable $e) {
            Log::warning('Google ID token verification failed', ['error' => $e->getMessage()]);
            throw new BusinessLogicException('INVALID_AUTH_TOKEN', 'Gagal memverifikasi akun Google: '.$e->getMessage(), 401);
        }
    }
}
