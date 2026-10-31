import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dev/mascot_gallery_screen.dart';
import '../../features/auth/presentation/onboarding_login_screen.dart';
import '../../features/collections/presentation/collections_screen.dart';
import '../../features/home_feed/presentation/home_screen.dart';
import '../../features/link_detail/presentation/link_detail_screen.dart';
import '../../features/paywall/presentation/paywall_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/share_intent/presentation/quick_share_host_screen.dart';
import '../../shared/models/link_model.dart';
import '../storage/local_storage_service.dart';
import '../storage/storage_provider.dart';

/// Route names / paths of the Tautin app.
abstract final class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String quickShare = '/share';
  static const String paywall = '/paywall';
  static const String collections = '/collections';
  static const String settings = '/settings';
  static const String linkDetail = '/home/detail/:id';
  // TODO(dev): temporary mascot preview route — remove with the screen.
  static const String devMascot = '/dev/mascot';
}

/// App navigation graph.
///
/// The initial location resolves synchronously from `authBox` so a returning
/// user lands directly on the home shell without a splash flash.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final LocalStorage storage = ref.watch(localStorageProvider);
  final bool signedIn = storage.hasSession;

  // TODO(dev): `--dart-define=PREVIEW_ROUTE=/dev/mascot` forces the initial
  // screen for device previews. Remove with the mascot gallery screen.
  const String previewRoute = String.fromEnvironment('PREVIEW_ROUTE');

  return GoRouter(
    initialLocation: previewRoute.isNotEmpty
        ? previewRoute
        : (signedIn ? AppRoutes.home : AppRoutes.onboarding),
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
        routes: <RouteBase>[
          GoRoute(
            path: 'detail/:id',
            name: 'linkDetail',
            builder: (BuildContext context, GoRouterState state) {
              final int id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              final LinkModel? link = state.extra is LinkModel ? state.extra as LinkModel : null;
              return LinkDetailScreen(linkId: id, initialLink: link);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.quickShare,
        name: 'quickShare',
        builder: (BuildContext context, GoRouterState state) {
          final Object? extra = state.extra;
          final String sharedText = extra is String ? extra : '';
          return QuickShareHostScreen(sharedText: sharedText);
        },
      ),
      GoRoute(
        path: AppRoutes.paywall,
        name: 'paywall',
        builder: (BuildContext context, GoRouterState state) =>
            const PaywallScreen(),
      ),
      GoRoute(
        path: AppRoutes.collections,
        name: 'collections',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: SafeArea(child: CollectionsScreen())),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      // TODO(dev): temporary mascot preview route — remove with the screen.
      GoRoute(
        path: AppRoutes.devMascot,
        name: 'devMascot',
        builder: (BuildContext context, GoRouterState state) =>
            const MascotGalleryScreen(),
      ),
    ],
  );
});
