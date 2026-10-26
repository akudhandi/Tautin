import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/storage_provider.dart';
import '../../../shared/models/collection_model.dart';
import '../../../shared/models/user_model.dart';
import '../domain/auth_session.dart';

/// Result contract of [AuthRepository.loginWithGoogleIdToken].
///
/// The repository persists token + user + collections in Hive BEFORE
/// returning, so the UI can navigate home immediately with cached folders.
abstract interface class AuthRepository {
  Future<AuthSession> loginWithGoogleIdToken(String idToken, {String? fcmToken});

  Future<void> logout();
}

/// HTTP implementation backed by Dio + Hive.
class TautinAuthRepository implements AuthRepository {
  TautinAuthRepository({required Dio dio, required LocalStorage storage})
    : _dio = dio,
      _storage = storage;

  final Dio _dio;
  final LocalStorage _storage;

  @override
  Future<AuthSession> loginWithGoogleIdToken(
    String idToken, {
    String? fcmToken,
  }) async {
    final Response<dynamic> response = await _dio.post<Object?>(
      '/auth/google',
      data: <String, dynamic>{
        'id_token': idToken,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
      },
    );

    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final Map<String, dynamic> data =
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>();

    final String token = data['token'] as String? ?? '';
    if (token.isEmpty) {
      throw const TautinApiException(
        message: 'Server tidak mengembalikan token sesi.',
      );
    }

    final UserModel user = UserModel.fromJson(
      (data['user'] as Map? ?? <Object?, Object?>{}).cast<String, dynamic>(),
    );

    final List<CollectionModel> collections =
        (data['collections'] as List? ?? <Object?>[])
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> c) =>
                  CollectionModel.fromJson(c.cast<String, dynamic>()),
            )
            .toList(growable: false);

    // Persist session + offline-ready collections in one shot.
    _storage.saveSanctumToken(token);
    _storage.saveUser(user);
    await _storage.saveCollections(collections);

    return AuthSession(
      token: token,
      user: user,
      collections: collections,
      isNewUser: data['is_new_user'] == true,
      message: envelope.message,
    );
  }

  @override
  Future<void> logout() async {
    // No server-side revoke endpoint in Phase 1-3; dropping the local Sanctum
    // token + mirrors is enough and always succeeds, even offline.
    await _storage.clearSession();
    await _storage.clearCollections();
  }
}

/// Riverpod wiring; overridable in tests with fakes.
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (Ref ref) => TautinAuthRepository(
    dio: ref.watch(dioProvider),
    storage: ref.watch(localStorageProvider),
  ),
);
