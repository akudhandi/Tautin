import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/sync/offline_flush_lifecycle.dart';
import 'core/theme/tautin_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/share_intent/presentation/share_intent_watcher.dart';

/// Root widget: theme dispatch + router + share-intent listener + offline
/// queue flush on app resume.
class TautinApp extends ConsumerWidget {
  const TautinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return ShareIntentWatcher(
      child: OfflineFlushLifecycle(
        child: MaterialApp.router(
          title: 'Tautin',
          debugShowCheckedModeBanner: false,
          theme: TautinTheme.light,
          darkTheme: TautinTheme.dark,
          themeMode: themeMode,
          routerConfig: router,
        ),
      ),
    );
  }
}
