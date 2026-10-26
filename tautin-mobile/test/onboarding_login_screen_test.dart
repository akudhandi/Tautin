import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tautin/core/network/api_exceptions.dart';
import 'package:tautin/core/router/app_router.dart' show AppRoutes;
import 'package:tautin/features/auth/data/auth_repository.dart';
import 'package:tautin/features/auth/data/google_auth_service.dart';
import 'package:tautin/features/auth/domain/auth_session.dart';
import 'package:tautin/features/auth/presentation/onboarding_login_screen.dart';
import 'package:tautin/features/auth/providers/auth_providers.dart';
import 'package:tautin/shared/models/models.dart';

/// Google wrapper fake: no plugin channel, deterministic id_token / failure.
class _FakeGoogleAuthService extends GoogleAuthService {
  _FakeGoogleAuthService({this.failureMessage});

  final String? failureMessage;
  int callCount = 0;

  @override
  Future<String> getIdToken() async {
    callCount++;
    final String? failure = failureMessage;
    if (failure != null) {
      throw GoogleAuthFailure(failure);
    }
    return 'fake-id-token';
  }
}

/// Repository fake: records calls, optionally throws a backend-shaped error.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.backendMessage});

  final String? backendMessage;
  int callCount = 0;
  String? lastIdToken;

  @override
  Future<AuthSession> loginWithGoogleIdToken(
    String idToken, {
    String? fcmToken,
  }) async {
    callCount++;
    lastIdToken = idToken;
    final String? failure = backendMessage;
    if (failure != null) {
      throw TautinApiException(message: failure);
    }

    return AuthSession(
      token: 'sanctum-token',
      user: const UserModel(
        id: 19,
        name: 'Rani Maharani',
        email: 'rani@example.com',
      ),
      collections: const <CollectionModel>[
        CollectionModel(id: 7, name: 'Belanja & Wishlist', isDefault: true),
      ],
      isNewUser: true,
      message: 'Login berhasil.',
    );
  }

  @override
  Future<void> logout() async {}
}

Future<GoRouter> _pumpOnboarding(
  WidgetTester tester, {
  required _FakeGoogleAuthService google,
  required _FakeAuthRepository auth,
}) async {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.onboarding,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) => const Scaffold(
          body: Center(child: Text('Beranda tersinkron.')),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        googleAuthServiceProvider.overrideWithValue(google),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();

  return router;
}

void main() {
  testWidgets('walks through the 3 Indonesian slides', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpOnboarding(
      tester,
      google: _FakeGoogleAuthService(),
      auth: _FakeAuthRepository(),
    );

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      AppRoutes.onboarding,
    );
    expect(find.text('Tinggal Share ke Tautin'), findsOneWidget);
    expect(
      find.textContaining('pilih Tautin. Tautan langsung tersimpan'),
      findsOneWidget,
    );
    expect(find.text('Lanjutkan dengan Google'), findsOneWidget);

    // Slide 1 -> 2
    await tester.tap(find.text('Lanjutkan'));
    // Two-step pumping: the first frame starts the PageView ticker
    // (elapsed = 0), the second advances past the 300ms animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(); // render the frame scheduled by onPageChanged
    expect(find.text('AI Merangkum & Merapikan'), findsOneWidget);
    expect(find.text('Tinggal Share ke Tautin'), findsNothing);

    // Slide 2 -> 3. The primary button stays enabled on the last page as
    // "Mulai Sekarang".
    await tester.tap(find.text('Lanjutkan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(); // render the frame scheduled by onPageChanged
    expect(find.text('Anti Lupa dengan Pengingat'), findsOneWidget);
    expect(
      find.textContaining('memasang pengingat'),
      findsOneWidget,
    );
    expect(find.text('Mulai Sekarang'), findsOneWidget);
  });

  testWidgets('login with Google persists a session and lands on /home', (
    WidgetTester tester,
  ) async {
    final _FakeGoogleAuthService google = _FakeGoogleAuthService();
    final _FakeAuthRepository auth = _FakeAuthRepository();

    final GoRouter router = await _pumpOnboarding(
      tester,
      google: google,
      auth: auth,
    );

    await tester.tap(find.text('Lanjutkan dengan Google'));
    await tester.pump(); // starts the flow
    await tester.pump(const Duration(milliseconds: 100)); // flush microtasks
    await tester.pump(
      const Duration(seconds: 1),
    ); // let the onboarding route transition out

    expect(google.callCount, 1);
    expect(auth.callCount, 1);
    expect(auth.lastIdToken, 'fake-id-token');
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      AppRoutes.home,
    );
    expect(find.text('Beranda tersinkron.'), findsOneWidget);
    expect(find.text('Lanjutkan dengan Google'), findsNothing);
  });

  testWidgets('cancelled Google sign-in shows an Indonesian snackbar', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpOnboarding(
      tester,
      google: _FakeGoogleAuthService(failureMessage: 'Proses login dibatalkan.'),
      auth: _FakeAuthRepository(),
    );

    await tester.tap(find.text('Lanjutkan dengan Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Proses login dibatalkan.'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      AppRoutes.onboarding,
    );

    // Let the 3s snackbar timer expire so the test ends without timers.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('backend failure surfaces its Indonesian message', (
    WidgetTester tester,
  ) async {
    await _pumpOnboarding(
      tester,
      google: _FakeGoogleAuthService(),
      auth: _FakeAuthRepository(backendMessage: 'Email sudah terpakai akun lain.'),
    );

    await tester.tap(find.text('Lanjutkan dengan Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Email sudah terpakai akun lain.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
