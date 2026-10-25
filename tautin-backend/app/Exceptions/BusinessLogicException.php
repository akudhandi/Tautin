<?php

namespace App\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BusinessLogicException extends Exception
{
    public function __construct(
        public string $errorCode,
        string $message,
        public int $httpStatus = 400,
        public mixed $errors = null,
        ?\Throwable $previous = null
    ) {
        parent::__construct($message, $httpStatus, $previous);
    }

    /**
     * Render the exception into an HTTP response.
     */
    public function render(Request $request): JsonResponse
    {
        $payload = [
            'success' => false,
            'error_code' => $this->errorCode,
            'message' => $this->getMessage(),
        ];

        if ($this->errors !== null) {
            $payload['errors'] = $this->errors;
        }

        return response()->json($payload, $this->httpStatus);
    }
}
