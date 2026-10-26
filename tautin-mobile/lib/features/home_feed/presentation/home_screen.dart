import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/storage_provider.dart';
import '../../../core/theme/tautin_theme.dart';
import '../../../shared/models/models.dart';

/// Minimal Phase 4 home shell.
///
/// Phase 5 replaces the body with the smart feed; the Phase 4 goal is a
/// valid landing route after login that already mirrors fresh user data.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LocalStorage storage = ref.watch(localStorageProvider);
    final UserModel? user = storage.user;
    final List<CollectionModel> collections = storage.loadCollections();

    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const _TautinLogo(),
        actions: <Widget>[_QuotaBadge(user: user)],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              '🏠',
              style: TextStyle(fontSize: 52),
            ),
            const SizedBox(height: 16),
            Text(
              'Beranda',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              collections.isEmpty
                  ? 'Koleksi kamu akan muncul di sini.'
                  : '${collections.length} koleksi tersinkron di perangkat.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TautinLogo extends StatelessWidget {
  const _TautinLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                TautinColors.primaryIndigo,
                TautinColors.aiViolet,
              ],
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'T',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Tautin',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
      ],
    );
  }
}

class _QuotaBadge extends StatelessWidget {
  const _QuotaBadge({required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    if (user?.isPro ?? false) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Chip(
          avatar: Text('👑'),
          label: Padding(
            padding: EdgeInsets.all(6),
            child: Text('PRO'),
          ),
        ),
      );
    }

    final int quota = user?.aiQuotaLeft ?? 10;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Chip(
        avatar: const Padding(
          padding: EdgeInsets.all(6),
          child: Text('✨'),
        ),
        label: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            'AI: $quota/10',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
