/// Domain exceptions thrown by the Tautin networking stack.
class TautinApiException implements Exception {
  const TautinApiException({
    required this.message,
    this.errorCode,
    this.statusCode,
    this.dioType,
    this.isConnectionError = false,
  });

  /// Human-friendly Indonesian message (already localized by the backend
  /// envelope or mapped locally for network failures).
  final String message;

  /// Stable machine code from `error_code`:
  /// `VALIDATION_ERROR`, `COLLECTION_LIMIT_REACHED`,
  /// `PRO_REQUIRED_FOR_REMINDER`, `PUBLIC_COLLECTION_LIMIT_REACHED`,
  /// `INVALID_PURCHASE_TOKEN`, `RATE_LIMIT_EXCEEDED`, ...
  final String? errorCode;

  final int? statusCode;

  /// `DioExceptionType` string, kept for diagnostics/tests.
  final String? dioType;

  /// True when the request never reached the server (offline / timeout).
  /// Drives the offline queue in the Quick Taut flow.
  final bool isConnectionError;

  @override
  String toString() =>
      'TautinApiException(code: $errorCode, status: $statusCode, message: $message)';
}
