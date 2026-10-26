import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:tautin/core/network/api_exceptions.dart';
import 'package:tautin/core/storage/local_storage_service.dart';
import 'package:tautin/features/share_intent/data/link_repository.dart';
import 'package:tautin/features/share_intent/data/offline_sync_service.dart';
import 'package:tautin/shared/models/models.dart';

class _QuickSaveRecord {
  const _QuickSaveRecord({required this.url, this.rawDescription});

  final String url;
  final String? rawDescription;
}

class _ScriptedLinkRepository implements LinkRepository {
  _ScriptedLinkRepository(this.quickSaveHandlers);

  final List<QuickSaveOutcome Function(_QuickSaveRecord)> quickSaveHandlers;

  final List<_QuickSaveRecord> calls = <_QuickSaveRecord>[];

  @override
  Future<QuickSaveOutcome> quickSave({
    required String url,
    String? rawDescription,
    int? collectionId,
    String? userNotes,
  }) {
    final _QuickSaveRecord record = _QuickSaveRecord(
      url: url,
      rawDescription: rawDescription,
    );
    calls.add(record);

    final int index = (calls.length - 1).clamp(0, quickSaveHandlers.length - 1);
    final QuickSaveOutcome Function(_QuickSaveRecord) handler =
        quickSaveHandlers[index];
    return Future<QuickSaveOutcome>.sync(() => handler(record));
  }

  @override
  Future<LinkModel> updateLink(
    int id, {
    int? collectionId,
    String? userNotes,
    bool? isPinned,
    bool? isRead,
    String? title,
  }) {
    throw UnimplementedError('updateLink is not exercised in these tests');
  }
}

const LinkModel _kAnyLink = LinkModel(
  id: 11,
  userId: 7,
  url: 'https://example.com/flushed',
  urlHash: 'hash',
  domain: 'example.com',
);

QuickSaveOutcome _stored(_QuickSaveRecord record) => QuickSaveOutcome(
      link: _kAnyLink.copyWith(url: record.url),
      isDuplicate: false,
      message: 'Tautan berhasil disimpan.',
    );

const TautinApiException _kConnectionError = TautinApiException(
  message: 'Koneksi internet tidak tersedia.',
  isConnectionError: true,
);

late Directory _tempDir;
late LocalStorage _storage;

OfflineSyncService _service(_ScriptedLinkRepository repo) =>
    OfflineSyncService(storage: _storage, links: repo);

void main() {
  setUpAll(() async {
    _tempDir = await Directory.systemTemp.createTemp('tautin_offline_hive');
    Hive.init(_tempDir.path);
    _storage = await LocalStorage.openBoxes();
  });

  setUp(() async {
    await _storage.clearAll();
    // flushPendingLinks is gated behind an active Sanctum session.
    _storage.saveSanctumToken('sanctum-token');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      if (_tempDir.existsSync()) {
        _tempDir.deleteSync(recursive: true);
      }
    } on FileSystemException {
      // Windows file locks during teardown are harmless.
    }
  });

  test('queue() parks quick-save payloads in offlineLinksQueueBox', () async {
    final _ScriptedLinkRepository repo = _ScriptedLinkRepository(
      <QuickSaveOutcome Function(_QuickSaveRecord)>[],
    );
    final OfflineSyncService service = _service(repo);

    await service.queue(<String, dynamic>{
      'url': 'https://a.example.com/artikel',
      'raw_description': 'Simpan buat dibaca nanti',
    });

    expect(_storage.pendingOfflineCount, 1);
    expect(service.hasPending, isTrue);

    final Map<String, dynamic> payload = LocalStorage.quickSavePayloadOf(
      _storage.readOfflineQueue().single,
    );
    expect(payload['url'], 'https://a.example.com/artikel');
    expect(payload['raw_description'], 'Simpan buat dibaca nanti');
    expect(repo.calls, isEmpty);
  });

  test('flushPendingLinks is a no-op with an empty queue', () async {
    final _ScriptedLinkRepository repo = _ScriptedLinkRepository(
      <QuickSaveOutcome Function(_QuickSaveRecord)>[],
    );
    final OfflineSyncService service = _service(repo);

    expect(await service.flushPendingLinks(), 0);
    expect(repo.calls, isEmpty);
  });

  test('flushes queued links sequentially in order online', () async {
    await _storage.enqueueOfflineLink(
      payload: <String, dynamic>{'url': 'https://a.example.com/1'},
    );
    await _storage.enqueueOfflineLink(
      payload: <String, dynamic>{'url': 'https://b.example.com/2'},
    );

    final _ScriptedLinkRepository repo = _ScriptedLinkRepository(
      <QuickSaveOutcome Function(_QuickSaveRecord)>[
        _stored,
        _stored,
      ],
    );

    expect(await _service(repo).flushPendingLinks(), 2);
    expect(repo.calls.map((_QuickSaveRecord c) => c.url).toList(),
        <String>['https://a.example.com/1', 'https://b.example.com/2']);
    expect(_storage.pendingOfflineCount, 0);
  });

  test('stops soft on connection errors and keeps the tail queued', () async {
    await _storage.enqueueOfflineLink(
      payload: <String, dynamic>{'url': 'https://a.example.com/1'},
    );
    await _storage.enqueueOfflineLink(
      payload: <String, dynamic>{'url': 'https://b.example.com/2'},
    );

    final _ScriptedLinkRepository repo = _ScriptedLinkRepository(
      <QuickSaveOutcome Function(_QuickSaveRecord)>[
        _stored,
        (_) => throw _kConnectionError,
      ],
    );

    final int synced = await _service(repo).flushPendingLinks();

    expect(synced, 1);
    expect(_storage.pendingOfflineCount, 1);
    expect(
      LocalStorage.quickSavePayloadOf(_storage.readOfflineQueue().single)['url'],
      'https://b.example.com/2',
    );
  });

  test('drops poisoned entries on permanent failures and keeps flushing', () async {
    await _storage.enqueueOfflineLink(
      payload: <String, dynamic>{'url': 'https://broken.example.com/x'},
    );
    await _storage.enqueueOfflineLink(
      payload: <String, dynamic>{'url': 'https://good.example.com/y'},
    );

    final _ScriptedLinkRepository repo = _ScriptedLinkRepository(
      <QuickSaveOutcome Function(_QuickSaveRecord)>[
        (_) => throw const TautinApiException(
              message: 'URL tidak valid.',
              statusCode: 422,
              errorCode: 'VALIDATION_ERROR',
            ),
        _stored,
      ],
    );

    expect(await _service(repo).flushPendingLinks(), 1);
    expect(_storage.pendingOfflineCount, 0);
    expect(
      repo.calls.map((_QuickSaveRecord c) => c.url).toList(),
      <String>['https://broken.example.com/x', 'https://good.example.com/y'],
    );
  });
}
