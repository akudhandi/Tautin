import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tautin/core/theme/tautin_theme.dart';
import 'package:tautin/features/collections/presentation/collection_detail_screen.dart';
import 'package:tautin/features/collections/presentation/collections_screen.dart';
import 'package:tautin/features/collections/presentation/widgets/create_collection_sheet.dart';
import 'package:tautin/features/collections/providers/collections_providers.dart';
import 'package:tautin/features/share_intent/data/link_repository.dart';
import 'package:tautin/shared/models/collection_model.dart';
import 'package:tautin/shared/models/link_model.dart';

class _FakeCollectionsNotifier extends AsyncNotifier<List<CollectionModel>>
    implements CollectionsNotifier {
  _FakeCollectionsNotifier(this._initial);

  final List<CollectionModel> _initial;

  @override
  Future<List<CollectionModel>> build() async => _initial;

  @override
  Future<CollectionModel> createCollection({
    required String name,
    String? icon,
    String? color,
    bool isPublic = false,
  }) async {
    final CollectionModel created = CollectionModel(
      id: 999,
      name: name,
      icon: icon ?? 'folder',
      color: color ?? '#A9E0F1',
      isPublic: isPublic,
    );
    state = AsyncData<List<CollectionModel>>(<CollectionModel>[
      ...state.value ?? <CollectionModel>[],
      created,
    ]);
    return created;
  }

  @override
  Future<CollectionModel> updateCollection(
    int id, {
    String? name,
    String? icon,
    String? color,
    bool? isPublic,
    String? slug,
  }) async {
    final List<CollectionModel> list = state.value ?? <CollectionModel>[];
    final int idx = list.indexWhere((CollectionModel c) => c.id == id);
    if (idx != -1) {
      final CollectionModel updated = list[idx].copyWith(
        name: name,
        icon: icon,
        color: color,
        isPublic: isPublic,
        slug: slug,
      );
      final List<CollectionModel> next = List<CollectionModel>.from(list);
      next[idx] = updated;
      state = AsyncData<List<CollectionModel>>(next);
      return updated;
    }
    return list.first;
  }

  @override
  Future<void> deleteCollection(int id) async {
    final List<CollectionModel> list = state.value ?? <CollectionModel>[];
    state = AsyncData<List<CollectionModel>>(
      list.where((CollectionModel c) => c.id != id).toList(),
    );
  }

  @override
  Future<void> refresh() async {}
}

class _FakeLinkRepo implements LinkRepository {
  _FakeLinkRepo({this.links = const <LinkModel>[]});

  final List<LinkModel> links;

  @override
  Future<PaginatedLinks> fetchLinks({
    int page = 1,
    int? collectionId,
    bool unassigned = false,
    String? sourceType,
    String? tag,
    bool? isRead,
    String? search,
  }) async {
    return PaginatedLinks(
      links: links,
      currentPage: 1,
      lastPage: 1,
      total: links.length,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final List<CollectionModel> _kSampleCollections = <CollectionModel>[
  const CollectionModel(
    id: 1,
    name: 'Belanja & Wishlist',
    icon: 'shopping_bag',
    color: '#A9E0F1',
    linksCount: 18,
    isDefault: true,
  ),
  const CollectionModel(
    id: 2,
    name: 'Resep & Kuliner',
    icon: 'restaurant',
    color: '#CAFFA6',
    linksCount: 24,
    isPublic: true,
    isDefault: false,
  ),
  const CollectionModel(
    id: 3,
    name: 'Tontonan & Hiburan',
    icon: 'play',
    color: '#E3F5A4',
    linksCount: 9,
    isDefault: false,
  ),
];

void main() {
  group('CollectionsScreen Widget Tests (B1.7)', () {
    testWidgets('renders Screen 4 header, quota pill, cards, and create card in light mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionsProvider.overrideWith(
              () => _FakeCollectionsNotifier(_kSampleCollections),
            ),
          ],
          child: MaterialApp(
            theme: TautinTheme.light,
            home: const Scaffold(body: CollectionsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Heading: "Koleksimu"
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is RichText && w.text.toPlainText().contains('Koleksimu'),
        ),
        findsOneWidget,
      );

      // Search circle button
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // 48px Quota pill
      expect(find.text('2/10'), findsOneWidget); // 2 custom collections
      expect(find.text('koleksi gratis terpakai'), findsOneWidget);
      expect(find.text('Upgrade'), findsOneWidget);

      // Collection items
      expect(find.text('Belanja & Wishlist'), findsOneWidget);
      expect(find.text('18 tautan'), findsOneWidget);
      expect(find.text('Resep & Kuliner'), findsOneWidget);
      expect(find.text('24 tautan'), findsOneWidget);
      expect(find.text('Publik'), findsOneWidget);

      // Dashed Buat Koleksi card
      expect(find.text('Buat Koleksi'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('search filters collection list', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionsProvider.overrideWith(
              () => _FakeCollectionsNotifier(_kSampleCollections),
            ),
          ],
          child: MaterialApp(
            theme: TautinTheme.light,
            home: const Scaffold(body: CollectionsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap search icon
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Resep');
      await tester.pumpAndSettle();

      expect(find.text('Resep & Kuliner'), findsOneWidget);
      expect(find.text('Belanja & Wishlist'), findsNothing);
    });

    testWidgets('CreateCollectionSheet renders all 12 icons and 12 colors (Screen 11)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionsProvider.overrideWith(
              () => _FakeCollectionsNotifier(_kSampleCollections),
            ),
          ],
          child: MaterialApp(
            theme: TautinTheme.light,
            home: const Scaffold(
              body: CreateCollectionSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Koleksi Baru'), findsOneWidget);
      expect(find.text('2/10 terpakai'), findsOneWidget);
      expect(find.text('IKON'), findsOneWidget);
      expect(find.text('WARNA'), findsOneWidget);
      expect(find.text('Jadikan koleksi publik'), findsOneWidget);
      expect(find.text('Buat Koleksi'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('CollectionDetailScreen renders Screen 7 header and Screen 34 empty state', (
      WidgetTester tester,
    ) async {
      final _FakeLinkRepo fakeRepo = _FakeLinkRepo(links: <LinkModel>[]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkRepositoryProvider.overrideWithValue(fakeRepo),
            collectionsProvider.overrideWith(
              () => _FakeCollectionsNotifier(_kSampleCollections),
            ),
          ],
          child: MaterialApp(
            theme: TautinTheme.light,
            home: const CollectionDetailScreen(
              collectionId: 2,
              initialCollection: CollectionModel(
                id: 2,
                name: 'Resep & Kuliner',
                icon: 'restaurant',
                color: '#CAFFA6',
                isPublic: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Resep & Kuliner'), findsOneWidget);
      expect(find.text('Bagikan koleksi'), findsWidgets);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Artikel'), findsOneWidget);
      expect(find.text('Belum Dibaca'), findsOneWidget);

      // Screen 34 empty state
      expect(find.text('Koleksi ini masih kosong'), findsOneWidget);
      expect(find.text('Tambah tautan'), findsOneWidget);
    });
  });
}
