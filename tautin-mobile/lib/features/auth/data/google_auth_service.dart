import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';

/// Wraps `google_sign_in` and exposes only the Google `id_token` needed by
/// `POST /api/v1/auth/google`.
class GoogleAuthService {
  GoogleSignIn? _signIn;
  bool _initialized = false;

  /// Returns the Google `id_token` for the interactive sign-in flow.
  ///
  /// Throws [GoogleAuthFailure] with an Indonesian message when the flow is
  /// canceled or misconfigured so the UI can surface it directly.
  Future<String> getIdToken() async {
    try {
      await _ensureInitialized();

      final GoogleSignInAccount account = await _signIn!.authenticate();

      final String? idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleAuthFailure(
          'Gagal mengambil token Google. Periksa konfigurasi serverClientId.',
        );
      }
      return idToken;
    } on GoogleAuthFailure {
      rethrow;
    } on GoogleSignInException catch (e) {
      final bool canceled =
          e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.uiUnavailable;
      throw GoogleAuthFailure(
        canceled
            ? 'Proses login dibatalkan.'
            : 'Gagal masuk dengan Google. Coba lagi beberapa saat.',
      );
    } catch (_) {
      throw const GoogleAuthFailure(
        'Gagal masuk dengan Google. Coba lagi beberapa saat.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _signIn!.signOut();
    } catch (_) {
      // Sign-out failure should never block the UI; the backend session is
      // what actually matters and it is cleared independently.
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized && _signIn != null) {
      return;
    }
    final GoogleSignIn signIn = GoogleSignIn.instance;
    // `serverClientId` is the OAuth Web Client ID of the Laravel backend; it
    // makes the Android plugin return an `id_token` audience the backend can
    // verify. May be empty in local development, where the backend falls
    // back to trusting the assertion payload.
    await signIn.initialize(
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
    );
    _signIn = signIn;
    _initialized = true;
  }
}

/// User-facing Google Sign-In failure (message already in Indonesian).
class GoogleAuthFailure implements Exception {
  const GoogleAuthFailure(this.message);

  final String message;

  @override
  String toString() => 'GoogleAuthFailure: $message';
}
