<?php

namespace App\Exceptions;

use Exception;

class UnsafeUrlException extends Exception
{
    public function __construct(string $message = 'URL tidak aman atau berada di jaringan internal terlarang.', int $code = 400, ?\Throwable $previous = null)
    {
        parent::__construct($message, $code, $previous);
    }
}
