import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/local_storage_service.dart';
import '../storage/storage_provider.dart';
import 'auth_interceptor.dart';

/// Provides the app-wide [Dio] instance talking to `tautin-backend`.
///
/// Base URL is injected via `--dart-define=API_BASE_URL=...` so the same
/// binary runs against the emulator (10.0.2.2), a LAN device, or production.
final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final LocalStorage storage = ref.watch(localStorageProvider);

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: <String, String>{'Content-Type': 'application/json'},
      validateStatus: (int? code) => code != null && code >= 200 && code < 500,
    ),
  );

  dio.interceptors.add(AuthInterceptor(storage));

  return dio;
});
