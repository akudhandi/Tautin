import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/onboarding_login_screen.dart';
import '../../features/home_feed/presentation/home_screen.dart';
import '../../features/share_intent/presentation/quick_share_host_screen.dart';
import '../storage/local_storage_service.dart';
import '../storage/storage_provider.dart';

/// Route names / paths of the Phase 4 shell.
abstract final class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String quickShare = '/share';
}

/// App navigation graph.
///
/// The initial location resolves synchronously from `authBox` so a returning
/// user lands directly on the home shell without a splash flash.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final LocalStorage storage = ref.watch(localStorageProvider);
  final bool signedIn = storage.hasSession;

  return GoRouter(
    initialLocation: signedIn ? AppRoutes.home : AppRoutes.onboarding,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingLoginScreen(key: ValueKey<String>(AppRoutes.onboarding)),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (BuildContext context, GoRouterState state) =>
            const HomeScreen(key: ValueKey<String>(AppRoutes.home)),
      ),
      GoRoute(
        path: AppRoutes.quickShare,
        name: 'quickShare',
        builder: (BuildContext context, GoRouterState state) {
          final Object? extra = state.extra;
          final String sharedText =
              extra is String ? extra : '';
          return QuickShareHostScreen(sharedText: sharedText);
        },
      ),
    ],
  );
});
