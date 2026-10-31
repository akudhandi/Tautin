import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tautin/core/theme/tautin_theme.dart';
import 'package:tautin/features/home_feed/providers/feed_providers.dart';
import 'package:tautin/features/search/presentation/search_screen.dart';
import 'package:tautin/shared/models/link_model.dart';

class _FakeFeedController extends FeedController {
  _FakeFeedController(this._links);

  final List<LinkModel> _links;

  @override
  Future<FeedState> build() async {
    final String search = ref.watch(searchQueryProvider);
    final FeedFilter filter = ref.watch(activeFilterProvider);

    List<LinkModel> links = _links;
    if (search.isNotEmpty) {
      final String q = search.toLowerCase();
      links = links
          .where(
            (LinkModel l) =>
                (l.title?.toLowerCase().contains(q) ?? false) ||
                (l.aiSummary?.toLowerCase().contains(q) ?? false) ||
                (l.userNotes?.toLowerCase().contains(q) ?? false) ||
                l.tags.any((t) => t.name.toLowerCase().contains(q)),
          )
          .toList();
    }
    if (filter.sourceType != null) {
      links =
          links.where((LinkModel l) => l.sourceType == filter.sourceType).toList();
    }

    return FeedState(
      links: links,
      currentPage: 1,
      lastPage: 1,
    );
  }

  @override
  Future<void> loadNextPage() async {}
}

const List<LinkModel> _kSampleLinks = <LinkModel>[
  LinkModel(
    id: 1,
    userId: 1,
    url: 'https://tiktok.com/video/1',
    urlHash: 'h1',
    domain: 'tiktok.com',
    sourceType: 'video',
    title: 'Ayam Bawang Putih Crispy Anti Gagal',
    aiSummary:
        'Ayam goreng yang renyah. Bahan utama: ayam, bawang putih, tepung maizena.',
    createdAt: 'baru',
  ),
  LinkModel(
    id: 2,
    userId: 1,
    url: 'https://instagram.com/p/2',
    urlHash: 'h2',
    domain: 'instagram.com',
    sourceType: 'social',
    title: 'Masak Enak Cek!',
    aiSummary: 'Tumis kangkung bawang putih pedas, siap dalam 10 menit.',
    createdAt: 'baru',
  ),
  LinkModel(
    id: 3,
    userId: 1,
    url: 'https://youtube.com/watch?v=3',
    urlHash: 'h3',
    domain: 'youtube.com',
    sourceType: 'video',
    title: 'Resep Capcay Kuah Sederhana',
    userNotes: 'tambah bawang putih 3 siung dan sedikit lada.',
    createdAt: 'baru',
  ),
];

void main() {
  group('SearchScreen Widget Tests (B1.9)', () {
    testWidgets(
      'renders focused search field, chips, found row, and result cards in light mode',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              feedProvider.overrideWith(() => _FakeFeedController(_kSampleLinks)),
            ],
            child: MaterialApp(
              theme: TautinTheme.light,
              home: const SearchScreen(initialQuery: 'bawang putih'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Search field shows the query
        expect(find.text('bawang putih'), findsOneWidget);

        // Filter chips (Screen 6: Semua, Video, Belanja, Artikel, Belum Dibaca)
        expect(find.text('Semua'), findsOneWidget);
        expect(find.text('Video'), findsOneWidget);
        expect(find.text('Belanja'), findsOneWidget);
        expect(find.text('Artikel'), findsOneWidget);
        expect(find.text('Belum Dibaca'), findsOneWidget);

        // Found row
        expect(find.text('3 tautan ditemukan'), findsOneWidget);
        expect(
          find.text('Dicari di judul, ringkasan AI, catatan, dan tag'),
          findsOneWidget,
        );

        // Result cards
        expect(find.text('Ayam Bawang Putih Crispy Anti Gagal'), findsOneWidget);
        expect(find.text('Masak Enak Cek!'), findsOneWidget);
        expect(find.text('Resep Capcay Kuah Sederhana'), findsOneWidget);

        // Match chips
        expect(find.text('Cocok di ringkasan AI'), findsNWidgets(2));
        expect(find.text('Cocok di catatan pribadi'), findsOneWidget);

        // Try tags section
        expect(find.text('Coba juga'), findsOneWidget);
        expect(find.text('#resep-ayam'), findsOneWidget);
      },
    );

    testWidgets('shows Screen 33 empty state when nothing matches', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedProvider.overrideWith(() => _FakeFeedController(_kSampleLinks)),
          ],
          child: MaterialApp(
            theme: TautinTheme.light,
            home: const SearchScreen(initialQuery: 'resep rendang'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada yang cocok'), findsOneWidget);
      expect(
        find.text(
          'Tauti belum menemukan tautan untuk \u201Cresep rendang\u201D. Coba kata kunci lain atau simpan tautan barunya.',
        ),
        findsOneWidget,
      );
      expect(find.text('resep ayam'), findsOneWidget);
      expect(find.text('rendang sapi'), findsOneWidget);
      expect(find.text('masakan mudah'), findsOneWidget);
      expect(find.text('Simpan tautan baru'), findsOneWidget);
    });

    testWidgets('typing a query updates results via the shared provider', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedProvider.overrideWith(() => _FakeFeedController(_kSampleLinks)),
          ],
          child: MaterialApp(
            theme: TautinTheme.light,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no results section (not submitted)
      expect(find.text('3 tautan ditemukan'), findsNothing);

      await tester.enterText(find.byType(TextField), 'capcay');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('1 tautan ditemukan'), findsOneWidget);
      expect(find.text('Resep Capcay Kuah Sederhana'), findsOneWidget);
      // 'capcay' only matches the title, so no mockup match chip is shown.
      expect(find.text('Cocok di catatan pribadi'), findsNothing);
    });
  });
}
