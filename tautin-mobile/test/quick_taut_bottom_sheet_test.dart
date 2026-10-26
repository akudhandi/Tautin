import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:tautin/core/config/app_config.dart';
import 'package:tautin/core/network/api_exceptions.dart';
import 'package:tautin/core/storage/local_storage_service.dart';
import 'package:tautin/core/storage/storage_provider.dart';
import 'package:tautin/features/share_intent/data/link_repository.dart';
import 'package:tautin/features/share_intent/presentation/quick_taut_bottom_sheet.dart';
import 'package:tautin/shared/models/models.dart';

/// Recorded `POST /links/quick-save` call.
class _QuickSaveRecord {
  const _QuickSaveRecord({
    required this.url,
    this.rawDescription,
    this.collectionId,
    this.userNotes,
  });

  final String url;
  final String? rawDescription;
  final int? collectionId;
  final String? userNotes;
}

/// Recorded `PATCH /links/{id}` call.
class _PatchRecord {
  const _PatchRecord({required this.id, this.collectionId, this.userNotes});

  final int id;
  final int? collectionId;
  final String? userNotes;
}

/// Scriptable [LinkRepository] — no Dio, no network.
class _FakeLinkRepository implements LinkRepository {
  _FakeLinkRepository({
    this.quickSaveHandlers =
        const <QuickSaveOutcome Function(_QuickSaveRecord)>[],
    this.updateLinkHandler,
  });

  final List<QuickSaveOutcome Function(_QuickSaveRecord)> quickSaveHandlers;
  final LinkModel Function(_PatchRecord)? updateLinkHandler;

  final List<_QuickSaveRecord> quickSaveCalls = <_QuickSaveRecord>[];
  final List<_PatchRecord> patchCalls = <_PatchRecord>[];

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
      collectionId: collectionId,
      userNotes: userNotes,
    );
    quickSaveCalls.add(record);

    final QuickSaveOutcome Function(_QuickSaveRecord)? handler =
        quickSaveHandlers.isEmpty
        ? null
        : quickSaveHandlers[(quickSaveCalls.length - 1).clamp(
            0,
            quickSaveHandlers.length - 1,
          )];
    if (handler == null) {
      throw UnimplementedError('quickSave handler is not scripted');
    }
    // Future.sync converts synchronous throws (connection errors) into
    // failed futures exactly like a real Dio call.
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
    final _PatchRecord record = _PatchRecord(
      id: id,
      collectionId: collectionId,
      userNotes: userNotes,
    );
    patchCalls.add(record);

    final LinkModel Function(_PatchRecord)? handler = updateLinkHandler;
    if (handler == null) {
      throw UnimplementedError('updateLink handler is not scripted');
    }
    return Future<LinkModel>.sync(() => handler(record));
  }
}

const LinkModel _kSavedShopeeLink = LinkModel(
  id: 501,
  userId: 7,
  url: 'https://s.shopee.co.id/3Vja8nQXm',
  urlHash: 'hash-abc',
  domain: 's.shopee.co.id',
  title: 'Flash Sale Sepatu Lari',
);

const LinkModel _kPatchedShopeeLink = LinkModel(
  id: 501,
  userId: 7,
  url: 'https://s.shopee.co.id/3Vja8nQXm',
  urlHash: 'hash-abc',
  domain: 's.shopee.co.id',
  title: 'Flash Sale Sepatu Lari',
  collectionId: 7,
);

const String _kShopeeShareText =
    'Harga spesial 12.12! https://s.shopee.co.id/3Vja8nQXm ShaShopee! '
    'Jangan sampai telat checkout.';

const String _kShopeeRawDescription =
    'Harga spesial 12.12! ShaShopee! Jangan sampai telat checkout.';

const TautinApiException _kConnectionError = TautinApiException(
  message: 'Koneksi internet tidak tersedia.',
  isConnectionError: true,
);

late LocalStorage _storage;

/// Drains the 2s countdown so no periodic timers outlive the test.
Future<void> _drainCountdown(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required String sharedText,
  required _FakeLinkRepository repo,
}) async {
  // 640x1200 logical surface: the sheet is capped at 32% of screen height
  // (=384dp) so the header, URL preview, quota banner, chips, and action
  // buttons all fit without scrolling and nothing overflows in tests.
  tester.view.physicalSize = const Size(640 * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(_storage),
        linkRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return Center(
                child: TextButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (BuildContext sheetContext) =>
                          QuickTautBottomSheet(sharedText: sharedText),
                    );
                  },
                  child: const Text('BUKA QUICK TAUT'),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('BUKA QUICK TAUT'));
  await tester.pump(); // pushes the route + initState
  await tester.pump(const Duration(milliseconds: 260)); // settle entrance
}

void main() {
  setUpAll(() async {
    // Memory-backed Hive (bytes: [] => StorageBackendMemory): `put` futures
    // complete synchronously, which fake-async widget tests require.
    _storage = LocalStorage(
      authBox: await Hive.openBox<dynamic>(kAuthBox, bytes: Uint8List(0)),
      collectionsBox: await Hive.openBox<dynamic>(
        kCollectionsCacheBox,
        bytes: Uint8List(0),
      ),
      offlineQueueBox: await Hive.openBox<dynamic>(
        kOfflineLinksQueueBox,
        bytes: Uint8List(0),
      ),
    );
  });

  setUp(() async {
    await _storage.clearAll();
    _storage.saveUser(
      const UserModel(
        id: 7,
        name: 'Rani Maharani',
        email: 'rani@example.com',
        aiQuotaLeft: 3,
      ),
    );
    await _storage.saveCollections(<CollectionModel>[
      const CollectionModel(
        id: 7,
        name: 'Belanja & Wishlist',
        icon: 'shopping_bag',
        sortOrder: 0,
      ),
      const CollectionModel(
        id: 9,
        name: 'Resepi Favorit',
        icon: 'restaurant',
        sortOrder: 1,
      ),
    ]);
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('auto-saves with the AI chip and closes after the 2s countdown', (
    WidgetTester tester,
  ) async {
    final _FakeLinkRepository repo = _FakeLinkRepository(
      quickSaveHandlers: <QuickSaveOutcome Function(_QuickSaveRecord)>[
        (_) => const QuickSaveOutcome(
          link: _kSavedShopeeLink,
          isDuplicate: false,
          message: 'Tautan berhasil disimpan.',
          aiQuotaLeft: 2,
          planType: 'free',
        ),
      ],
    );

    await _pumpSheet(tester, sharedText: _kShopeeShareText, repo: repo);

    // The quick-save fired immediately with the parsed URL + raw description.
    expect(repo.quickSaveCalls, hasLength(1));
    expect(repo.quickSaveCalls.single.url, 'https://s.shopee.co.id/3Vja8nQXm');
    expect(repo.quickSaveCalls.single.rawDescription, _kShopeeRawDescription);
    expect(repo.quickSaveCalls.single.collectionId, isNull);
    expect(find.text('Tautan berhasil disimpan.'), findsOneWidget);

    // Folder chips render straight from the Hive cache (0ms).
    expect(find.text(AppConfig.aiAutoCollectionChip), findsOneWidget);
    expect(find.text('Belanja & Wishlist'), findsOneWidget);
    expect(find.text('Resepi Favorit'), findsOneWidget);

    // Quota badge mirrors the persisted profile.
    expect(find.text('✨ AI: 3/10'), findsOneWidget);

    // URL preview: domain + clean url.
    expect(find.text('s.shopee.co.id'), findsOneWidget);
    expect(find.text('https://s.shopee.co.id/3Vja8nQXm'), findsOneWidget);

    // Countdown bar is running in the saved state.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // 2s later the sheet closed itself and the opener shell is visible again.
    await _drainCountdown(tester);
    expect(find.byType(QuickTautBottomSheet), findsNothing);
    expect(find.text('BUKA QUICK TAUT'), findsOneWidget);
  });

  testWidgets('duplicate links surface the " dinaikkan ke paling atas!" copy', (
    WidgetTester tester,
  ) async {
    final _FakeLinkRepository repo = _FakeLinkRepository(
      quickSaveHandlers: <QuickSaveOutcome Function(_QuickSaveRecord)>[
        (_) => const QuickSaveOutcome(
          link: _kSavedShopeeLink,
          isDuplicate: true,
          message: '',
          aiQuotaLeft: 8,
        ),
      ],
    );

    await _pumpSheet(tester, sharedText: _kShopeeShareText, repo: repo);

    expect(
      find.text('Tautan sudah ada di Tautin, dinaikkan ke paling atas!'),
      findsOneWidget,
    );
    expect(_storage.pendingOfflineCount, 0);

    // No interaction: the countdown must still auto-close the sheet.
    await _drainCountdown(tester);
    expect(find.byType(QuickTautBottomSheet), findsNothing);
  });

  testWidgets('connection error parks the payload into the offline queue', (
    WidgetTester tester,
  ) async {
    final _FakeLinkRepository repo = _FakeLinkRepository(
      quickSaveHandlers: <QuickSaveOutcome Function(_QuickSaveRecord)>[
        (_) => throw _kConnectionError,
      ],
    );

    await _pumpSheet(tester, sharedText: _kShopeeShareText, repo: repo);

    expect(
      find.text(
        'Tersimpan di perangkat. Akan dirapikan AI saat terhubung ke internet.',
      ),
      findsOneWidget,
    );

    // Countdown bar hides for the offline state.
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // The dirty URL was parsed BEFORE the payload was parked.
    expect(_storage.pendingOfflineCount, 1);
    final Map<String, dynamic> payload = LocalStorage.quickSavePayloadOf(
      _storage.readOfflineQueue().single,
    );
    expect(payload['url'], 'https://s.shopee.co.id/3Vja8nQXm');
    expect(payload['raw_description'], _kShopeeRawDescription);
    expect(payload['collection_id'], isNull);

    // The periodic auto-close timer keeps draining (still no pending timers).
    await _drainCountdown(tester);
    expect(find.byType(QuickTautBottomSheet), findsNothing);
  });

  testWidgets(
    'texts without a URL show the Indonesian warning and skip the API',
    (WidgetTester tester) async {
      final _FakeLinkRepository repo = _FakeLinkRepository();

      await _pumpSheet(
        tester,
        sharedText: 'TEMUKAN KEBAHAGIAAN DI SINI, diskon gede2an!!!',
        repo: repo,
      );

      expect(
        find.text('Tidak ada tautan yang terdeteksi pada teks dibagikan.'),
        findsOneWidget,
      );
      expect(repo.quickSaveCalls, isEmpty);
      expect(repo.patchCalls, isEmpty);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(_storage.pendingOfflineCount, 0);
    },
  );

  testWidgets(
    'saved link without an AI summary shows the quota upsell banner',
    (WidgetTester tester) async {
      final _FakeLinkRepository repo = _FakeLinkRepository(
        quickSaveHandlers: <QuickSaveOutcome Function(_QuickSaveRecord)>[
          (_) => const QuickSaveOutcome(
            link: _kSavedShopeeLink,
            isDuplicate: false,
            message: 'Tautan berhasil disimpan.',
            aiQuotaLeft: 0,
            planType: 'free',
          ),
        ],
      );

      await _pumpSheet(tester, sharedText: _kShopeeShareText, repo: repo);

      expect(find.text(AppConfig.aiQuotaExhaustedBanner), findsOneWidget);

      await _drainCountdown(tester);
    },
  );

  testWidgets('saved link with an AI summary hides the quota upsell banner', (
    WidgetTester tester,
  ) async {
    final _FakeLinkRepository repo = _FakeLinkRepository(
      quickSaveHandlers: <QuickSaveOutcome Function(_QuickSaveRecord)>[
        (_) => const QuickSaveOutcome(
          link: LinkModel(
            id: 501,
            userId: 7,
            url: 'https://s.shopee.co.id/3Vja8nQXm',
            urlHash: 'hash-abc',
            domain: 's.shopee.co.id',
            title: 'Flash Sale Sepatu Lari',
            aiSummary: 'Sepatu lari ringan dengan harga diskon Rp349.000.',
          ),
          isDuplicate: false,
          message: 'Tautan berhasil disimpan.',
          aiQuotaLeft: 2,
          planType: 'free',
        ),
      ],
    );

    await _pumpSheet(tester, sharedText: _kShopeeShareText, repo: repo);

    expect(find.text(AppConfig.aiQuotaExhaustedBanner), findsNothing);

    await _drainCountdown(tester);
  });

  testWidgets(
    'tapping a collection chip cancels auto-close and PATCHes the link',
    (WidgetTester tester) async {
      final _FakeLinkRepository repo = _FakeLinkRepository(
        quickSaveHandlers: <QuickSaveOutcome Function(_QuickSaveRecord)>[
          (_) => const QuickSaveOutcome(
            link: _kSavedShopeeLink,
            isDuplicate: false,
            message: 'Tautan berhasil disimpan.',
          ),
        ],
        updateLinkHandler: (_PatchRecord call) => _kPatchedShopeeLink,
      );

      await _pumpSheet(tester, sharedText: _kShopeeShareText, repo: repo);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Belanja & Wishlist'));
      await tester.pump(const Duration(milliseconds: 200));

      // Auto-close canceled -> progress bar removed...
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // ...and the pending chip choice PATCHed right away.
      expect(repo.patchCalls, hasLength(1));
      expect(repo.patchCalls.single.id, 501);
      expect(repo.patchCalls.single.collectionId, 7);

      // Long wait: the sheet stays open because the timer was canceled.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(QuickTautBottomSheet), findsOneWidget);
    },
  );

  testWidgets('"Tambah Catatan" PATCHes user_notes and keeps the sheet open', (
    WidgetTester tester,
  ) async {
    final _FakeLinkRepository repo = _FakeLinkRepository(
      quickSaveHandlers: <QuickSaveOutcome Function(_QuickSaveRecord)>[
        (_) => const QuickSaveOutcome(
          link: _kSavedShopeeLink,
          isDuplicate: false,
          message: 'Tautan berhasil disimpan.',
        ),
      ],
      updateLinkHandler: (_PatchRecord call) => _kPatchedShopeeLink,
    );

    await _pumpSheet(tester, sharedText: _kShopeeShareText, repo: repo);

    await tester.tap(find.text('Tambah Catatan'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Tulis catatan pribadi...'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Simpan buat wishlist baju lebaran',
    );
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.patchCalls, hasLength(1));
    expect(repo.patchCalls.single.id, 501);
    expect(
      repo.patchCalls.single.userNotes,
      'Simpan buat wishlist baju lebaran',
    );
    expect(find.text('Catatan tersimpan.'), findsOneWidget);

    // Note interaction canceled the countdown as well.
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(QuickTautBottomSheet), findsOneWidget);
  });
}
