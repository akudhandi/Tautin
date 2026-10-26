import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/storage_provider.dart';
import 'link_repository.dart';

/// Offline queue manager for the Quick Taut flow.
///
/// When a share arrives without connectivity the payload is stored in
/// `offlineLinksQueueBox`; `flushPendingLinks()` is invoked on
/// `AppLifecycleState.resumed` (connection restored) and sends entries
/// sequentially so the backend worker queue is not hammered in bursts.
class OfflineSyncService {
  OfflineSyncService({required LocalStorage storage, required LinkRepository links})
    : _storage = storage,
      _links = links;

  final LocalStorage _storage;
  final LinkRepository _links;

  bool get hasPending => _storage.pendingOfflineCount > 0;

  /// Adds a quick-save payload for deferred processing.
  Future<void> queue(Map<String, dynamic> quickSavePayload) =>
      _storage.enqueueOfflineLink(payload: quickSavePayload);

  /// Sends all queued payloads in order.
  ///
  /// Returns the count of successfully synced links. Stops on the first
  /// connection error; non-connection errors (per-entry validation etc.)
  /// remove the entry to avoid poison-pill loops.
  Future<int> flushPendingLinks() async {
    if (!hasPending) {
      return 0;
    }

    int synced = 0;
    // Snapshot: new shares may append while we are flushing.
    final List<Map<String, dynamic>> entries = _storage.readOfflineQueue();

    for (final Map<String, dynamic> entry in entries) {
      if (!_storage.hasSession) {
        break;
      }
      final Map<String, dynamic> payload = LocalStorage.quickSavePayloadOf(entry);
      try {
        await _links.quickSave(
          url: payload['url'] as String? ?? '',
          rawDescription: payload['raw_description'] as String?,
          collectionId: payload['collection_id'] as int?,
          userNotes: payload['user_notes'] as String?,
        );
        await _storage.removeOfflineEntry(entry['id'] as String);
        synced++;
      } on TautinApiException catch (e) {
        if (e.isConnectionError) {
          // Internet still down — keep remaining entries for next resume.
          break;
        }
        // Fatal for this entry only; drop the poisoned payload.
        await _storage.removeOfflineEntry(entry['id'] as String);
      }
    }

    return synced;
  }
}

/// Overridable wiring for tests.
final Provider<OfflineSyncService> offlineSyncServiceProvider =
    Provider<OfflineSyncService>(
      (Ref ref) => OfflineSyncService(
        storage: ref.watch(localStorageProvider),
        links: ref.watch(linkRepositoryProvider),
      ),
    );
