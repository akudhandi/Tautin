import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_storage_service.dart';

/// Synchronously available Hive-backed storage.
///
/// `main()` initializes Hive before `runApp` and injects the ready instance
/// via `ProviderScope(overrides: [...])`; widget tests do the same with a
/// temporary directory.
final Provider<LocalStorage> localStorageProvider = Provider<LocalStorage>((
  Ref ref,
) {
  throw UnimplementedError(
    'localStorageProvider must be overridden before use '
    '(see LocalStorage.init in main.dart).',
  );
});
