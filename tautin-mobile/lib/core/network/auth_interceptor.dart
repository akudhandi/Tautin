import 'package:dio/dio.dart';

import '../../shared/models/plan_type.dart';
import '../storage/local_storage_service.dart';

/// Injects the Sanctum bearer token on every request and mirrors fresh
/// `meta.ai_quota_left` / `meta.plan_type` values delivered by any API
/// response back into the local user profile.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final LocalStorage _storage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? token = _storage.sanctumToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final dynamic raw = response.data;
    if (raw is Map) {
      final dynamic meta = raw['meta'];
      if (meta is Map) {
        final dynamic quota = meta['ai_quota_left'];
        final dynamic plan = meta['plan_type'];
        if (quota != null || plan != null) {
          _storage.updateUserQuota(
            aiQuotaLeft: quota == null ? null : (quota as num).toInt(),
            planType: plan == null ? null : PlanType.fromName(plan as String?),
          );
        }
      }
    }
    handler.next(response);
  }
}
