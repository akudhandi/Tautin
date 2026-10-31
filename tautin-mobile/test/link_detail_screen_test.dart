import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tautin/core/theme/tautin_theme.dart';
import 'package:tautin/features/link_detail/presentation/link_detail_screen.dart';
import 'package:tautin/features/share_intent/data/link_repository.dart';
import 'package:tautin/shared/models/collection_model.dart';
import 'package:tautin/shared/models/link_model.dart';
import 'package:tautin/shared/models/tag_model.dart';

class _FakeLinkRepo implements LinkRepository {
  _FakeLinkRepo();

  final List<Map<String, dynamic>> updateCalls = <Map<String, dynamic>>[];

  @override
  Future<LinkModel> updateLink(
    int id, {
    int? collectionId,
    String? userNotes,
    bool? isPinned,
    bool? isRead,
    String? title,
    DateTime? remindAt,
  }) async {
    updateCalls.add(<String, dynamic>{
      'id': id,
      'isPinned': isPinned,
      'isRead': isRead,
      'userNotes': userNotes,
      'remindAt': remindAt,
      'title': title,
    });
    return _kDetailTestLink.copyWith(
      isPinned: isPinned ?? _kDetailTestLink.isPinned,
      isRead: isRead ?? _kDetailTestLink.isRead,
      userNotes: userNotes ?? _kDetailTestLink.userNotes,
      remindAt: remindAt?.toIso8601String() ?? _kDetailTestLink.remindAt,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const LinkModel _kDetailTestLink = LinkModel(
  id: 301,
  userId: 1,
  url: 'https://vt.tiktok.com/ZSh4kP9x/',
  urlHash: 'hash-tiktok-301',
  domain: 'vt.tiktok.com',
  sourceType: 'video',
  title: 'Resep Ayam Bawang Putih Crispy',
  aiSummary: 'Marinasi ayam dengan bawang putih halus, ketumbar, dan maizena agar renyah.',
  userNotes: 'Cobain buat menu akhir pekan.',
  isPinned: false,
  isRead: false,
  collection: CollectionModel(
    id: 3,
    userId: 1,
    name: 'Resep Masakan',
    slug: 'resep-masakan',
  ),
  tags: <TagModel>[
    TagModel(id: 1, name: 'kuliner'),
    TagModel(id: 2, name: 'ayam'),
  ],
);

void main() {
  group('LinkDetailScreen Widget Tests (B1.6)', () {
    testWidgets('renders all mockup Screen 3 elements in light mode', (
      WidgetTester tester,
    ) async {
      final _FakeLinkRepo repo = _FakeLinkRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: TautinTheme.light,
            home: const LinkDetailScreen(
              linkId: 301,
              initialLink: _kDetailTestLink,
            ),
          ),
        ),
      );

      // Header title and back icon
      expect(find.text('Detail Tautan'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);

      // Hero banner with domain and type
      expect(find.text('video · vt.tiktok.com'), findsOneWidget);

      // Title & AI Summary
      expect(find.text('Resep Ayam Bawang Putih Crispy'), findsOneWidget);
      expect(find.text('RINGKASAN AI'), findsOneWidget);
      expect(
        find.text('Marinasi ayam dengan bawang putih halus, ketumbar, dan maizena agar renyah.'),
        findsOneWidget,
      );

      // Collection & Tags
      expect(find.text('Resep Masakan'), findsOneWidget);
      expect(find.text('#kuliner'), findsOneWidget);
      expect(find.text('#ayam'), findsOneWidget);

      // Private Notes & Reminder
      expect(find.text('CATATAN PRIBADI'), findsOneWidget);
      expect(find.text('Cobain buat menu akhir pekan.'), findsOneWidget);
      expect(find.text('Pasang Pengingat'), findsOneWidget);

      // Bottom Primary Button
      expect(find.text('Buka Tautan Asli'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_outward_rounded), findsOneWidget);
    });

    testWidgets('toggles pinned state on button tap', (
      WidgetTester tester,
    ) async {
      final _FakeLinkRepo repo = _FakeLinkRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: TautinTheme.light,
            home: const LinkDetailScreen(
              linkId: 301,
              initialLink: _kDetailTestLink,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.push_pin_rounded));
      await tester.pump();

      expect(repo.updateCalls, hasLength(1));
      expect(repo.updateCalls.first['isPinned'], isTrue);
    });

    testWidgets('toggles read status on row tap', (
      WidgetTester tester,
    ) async {
      final _FakeLinkRepo repo = _FakeLinkRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: TautinTheme.light,
            home: const LinkDetailScreen(
              linkId: 301,
              initialLink: _kDetailTestLink,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded));
      await tester.pump();

      expect(repo.updateCalls, hasLength(1));
      expect(repo.updateCalls.first['isRead'], isTrue);
    });
  });
}
