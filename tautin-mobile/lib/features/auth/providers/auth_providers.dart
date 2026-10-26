import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exceptions.dart';

import '../data/auth_repository.dart';
import '../data/google_auth_service.dart';

/// UI state of the onboarding login flow.
class AuthFlowState {
  const AuthFlowState({
    this.isLoading = false,
    this.errorMessage,
    this.completed = false,
  });

  final bool isLoading;
  final String? errorMessage;
  final bool completed;

  AuthFlowState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? completed,
  }) {
    return AuthFlowState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      completed: completed ?? this.completed,
    );
  }
}

/// Drives the "Lanjutkan dengan Google" button:
/// Google id_token -> `POST /auth/google` -> Hive persistence -> navigate.
class AuthFlowController extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() {
    return const AuthFlowState();
  }

  Future<void> signInWithGoogle({String? fcmToken}) async {
    state = const AuthFlowState(isLoading: true);
    try {
      final GoogleAuthService google = _googleService;
      final String idToken = await google.getIdToken();

      await ref.read(authRepositoryProvider).loginWithGoogleIdToken(
            idToken,
            fcmToken: fcmToken,
          );

      state = const AuthFlowState(isLoading: false, completed: true);
    } on GoogleAuthFailure catch (e) {
      state = AuthFlowState(errorMessage: e.message);
    } on TautinApiException catch (e) {
      state = AuthFlowState(errorMessage: e.message);
    } catch (_) {
      state = const AuthFlowState(
        errorMessage: 'Terjadi kesalahan tak terduga. Coba lagi.',
      );
    }
  }

  GoogleAuthService get _googleService => ref.watch(googleAuthServiceProvider);

  void clearError() {
    if (state.errorMessage != null) {
      state = AuthFlowState(isLoading: state.isLoading);
    }
  }
}

/// Login flow state machine (override in tests for deterministic success).
final NotifierProvider<AuthFlowController, AuthFlowState> authFlowProvider =
    NotifierProvider<AuthFlowController, AuthFlowState>(
  AuthFlowController.new,
);

/// Injectable Google Sign-In wrapper.
final Provider<GoogleAuthService> googleAuthServiceProvider =
    Provider<GoogleAuthService>((Ref ref) => GoogleAuthService());
