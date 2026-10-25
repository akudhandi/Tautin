<?php

namespace App\Http\Traits;

use Illuminate\Http\JsonResponse;

trait ApiResponseTrait
{
    /**
     * Return a standardized success JSON response.
     *
     * @param  array<string, mixed>  $meta
     */
    public function successResponse(mixed $data = null, string $message = 'Operasi berhasil.', int $code = 200, array $meta = []): JsonResponse
    {
        $payload = [
            'success' => true,
            'message' => $message,
            'data' => $data,
        ];

        if (! empty($meta)) {
            $payload['meta'] = $meta;
        }

        return response()->json($payload, $code);
    }

    /**
     * Return a standardized error JSON response.
     */
    public function errorResponse(string $errorCode, string $message, int $httpCode = 400, mixed $errors = null): JsonResponse
    {
        $payload = [
            'success' => false,
            'error_code' => $errorCode,
            'message' => $message,
        ];

        if ($errors !== null) {
            $payload['errors'] = $errors;
        }

        return response()->json($payload, $httpCode);
    }
}
