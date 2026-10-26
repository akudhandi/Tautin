import 'package:dio/dio.dart';

import 'api_exceptions.dart';

/// Standard Tautin JSON envelope.
///
/// ```json
/// { "success": true, "message": "...", "data": ..., "meta": {...} }
/// ```
class ApiEnvelope {
  const ApiEnvelope({
    required this.success,
    required this.message,
    this.data,
    this.meta,
  });

  final bool success;
  final String message;

  /// `data` may be a map, a list, or null depending on the endpoint.
  final dynamic data;
  final Map<String, dynamic>? meta;

  /// Builds the envelope from an already-decoded JSON body.
  static ApiEnvelope fromMap(dynamic raw) {
    if (raw is! Map) {
      throw TautinApiException(message: 'Respons server tidak valid.');
    }
    final dynamic meta = raw['meta'];
    return ApiEnvelope(
      success: raw['success'] == true,
      message: raw['message'] as String? ?? '',
      data: raw['data'],
      meta: meta is Map ? meta.cast<String, dynamic>() : null,
    );
  }

  /// Validates `success == true` then returns the envelope.
  ///
  /// 4xx envelopes handled by [TautinLinkRepository]-style callers carry the
  /// backend `error_code` (e.g. `INVALID_PURCHASE_TOKEN`), which is surfaced
  /// on the thrown exception for paywall/reminder handling in later phases.
  static ApiEnvelope requireSuccess(Response<dynamic> response) {
    final ApiEnvelope envelope = ApiEnvelope.fromMap(response.data);
    if (!envelope.success) {
      throw TautinApiException(
        message:
            envelope.message.isEmpty ? 'Permintaan gagal.' : envelope.message,
        errorCode: _errorCodeOf(response.data),
        statusCode: response.statusCode,
      );
    }
    return envelope;
  }

  static String? _errorCodeOf(dynamic raw) {
    if (raw is Map) {
      final dynamic code = raw['error_code'];
      return code is String ? code : null;
    }
    return null;
  }

  /// Maps a failing [DioException] into a friendly [TautinApiException].
  static TautinApiException exceptionFromDio(DioException error) {
    final dynamic raw = error.response?.data;
    final Map<String, dynamic>? body =
        raw is Map ? raw.cast<String, dynamic>() : null;
    final String? errorCode = body?['error_code'] as String?;

    final bool connectionError = switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      _ => false,
    };

    if (connectionError) {
      return TautinApiException(
        message: 'Koneksi internet tidak tersedia.',
        errorCode: errorCode,
        statusCode: error.response?.statusCode,
        dioType: error.type.name,
        isConnectionError: true,
      );
    }

    final String defaultMessage = switch (error.type) {
      DioExceptionType.badResponse ||
      DioExceptionType.badCertificate =>
        'Terjadi kesalahan pada server. Coba beberapa saat lagi.',
      DioExceptionType.cancel => 'Permintaan dibatalkan.',
      _ => 'Terjadi kesalahan tak terduga. Coba lagi.',
    };

    return TautinApiException(
      message: body?['message'] as String? ?? defaultMessage,
      errorCode: errorCode,
      statusCode: error.response?.statusCode,
      dioType: error.type.name,
      isConnectionError: false,
    );
  }
}

/// Useful accessors on the `meta` map of a [ApiEnvelope].
extension ApiEnvelopeMetaX on ApiEnvelope {
  /// `meta.is_duplicate` from `POST /links/quick-save`.
  bool get metaIsDuplicate => meta?['is_duplicate'] == true;

  /// `meta.ai_quota_left` when the backend attaches it to a response.
  int? get metaAiQuotaLeft {
    final dynamic value = meta?['ai_quota_left'];
    return value == null ? null : (value as num).toInt();
  }

  /// `meta.plan_type` when the backend attaches it to a response.
  String? get metaPlanType => meta?['plan_type'] as String?;
}
