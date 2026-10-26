import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/local_storage_service.dart';
import 'core/storage/storage_provider.dart';

/// Composition root: Hive opens first, then everything else runs inside
/// [ProviderScope] with the ready storage injected.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final LocalStorage storage = await LocalStorage.init();

  runApp(
    ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(storage)],
      child: const TautinApp(),
    ),
  );
}
