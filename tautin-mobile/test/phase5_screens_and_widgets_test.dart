import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tautin/core/config/app_config.dart';
import 'package:tautin/core/theme/tautin_theme.dart';
import 'package:tautin/features/paywall/presentation/paywall_screen.dart';
import 'package:tautin/shared/models/collection_model.dart';
import 'package:tautin/shared/models/link_model.dart';
import 'package:tautin/shared/models/tag_model.dart';
import 'package:tautin/shared/widgets/smart_link_card.dart';

void main() {
  group('SmartLinkCard Widget Tests', () {
    const LinkModel testLink = LinkModel(
      id: 101,
      userId: 1,
      url: 'https://shopee.co.id/product/123',
      urlHash: 'hash-shopee-123',
      domain: 'shopee.co.id',
      sourceType: 'ecommerce',
      title: 'Sepatu Lari Ortuseight Hyperglide',
      aiSummary: 'Sepatu running lokal dengan bantalan empuk dan responsif.',
      status: 'completed',
      isAiProcessed: true,
      isRead: false,
      isPinned: true,
      collection: CollectionModel(
        id: 5,
        userId: 1,
        name: 'Wishlist Belanja',
        slug: 'wishlist-belanja',
      ),
      tags: <TagModel>[
        TagModel(id: 1, name: 'sepatu'),
        TagModel(id: 2, name: 'running'),
      ],
    );

    testWidgets('renders title, domain, AI summary, collection chip and tags', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: TautinTheme.light,
          home: Scaffold(
            body: SmartLinkCard(
              link: testLink,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Sepatu Lari Ortuseight Hyperglide'), findsOneWidget);
      expect(find.textContaining('shopee.co.id'), findsWidgets);
      expect(
        find.text('Sepatu running lokal dengan bantalan empuk dan responsif.'),
        findsOneWidget,
      );
      expect(find.text('Wishlist Belanja'), findsOneWidget);
      expect(find.text('#sepatu'), findsOneWidget);
      expect(find.text('#running'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);

      await tester.tap(find.text('Sepatu Lari Ortuseight Hyperglide'));
      expect(tapped, isTrue);
    });

    testWidgets('renders quota upsell banner when AI summary is missing on completed link', (
      WidgetTester tester,
    ) async {
      bool quotaTapped = false;
      const LinkModel noAiLink = LinkModel(
        id: 102,
        userId: 1,
        url: 'https://tiktok.com/@chef/video/456',
        urlHash: 'hash-tiktok-456',
        domain: 'tiktok.com',
        sourceType: 'video',
        title: 'Resep Ayam Krispi',
        status: 'completed',
        isAiProcessed: true,
        aiSummary: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TautinTheme.light,
          home: Scaffold(
            body: SmartLinkCard(
              link: noAiLink,
              onQuotaBannerTap: () => quotaTapped = true,
            ),
          ),
        ),
      );

      expect(find.text(AppConfig.aiQuotaExhaustedBanner), findsOneWidget);

      await tester.tap(find.text(AppConfig.aiQuotaExhaustedBanner));
      expect(quotaTapped, isTrue);
    });
  });

  group('PaywallScreen Widget Tests', () {
    testWidgets('renders brand headline, benefits list, and plan options', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PaywallScreen(),
          ),
        ),
      );

      expect(find.text('Tautin Pro'), findsOneWidget);
      expect(find.text('Rapikan semua tautanmu,'), findsOneWidget);
      expect(find.text('tanpa batas.'), findsOneWidget);

      // Benefit points
      expect(
        find.text('Ringkasan, folder, dan tag AI tanpa batas'),
        findsOneWidget,
      );
      expect(find.text('Koleksi tanpa batas'), findsOneWidget);
      expect(find.text('Pengingat per tautan, tepat waktu'), findsOneWidget);
      expect(find.text('Bagikan koleksi publik tanpa batas'), findsOneWidget);

      // 3 Plans
      expect(find.text('Bulanan'), findsOneWidget);
      expect(find.text('Rp29.000'), findsOneWidget);
      expect(find.text('Tahunan'), findsOneWidget);
      expect(find.text('Rp249.000'), findsOneWidget);
      expect(find.text('Paling Hemat'), findsOneWidget);
      expect(find.text('Selamanya'), findsOneWidget);
      expect(find.text('Rp349.000'), findsOneWidget);
      expect(find.text('Early Bird'), findsOneWidget);

      // CTA
      expect(find.text('Mulai Tautin Pro'), findsOneWidget);
      expect(find.text('Pulihkan Pembelian'), findsOneWidget);

      // Select monthly plan
      await tester.ensureVisible(find.text('Bulanan'));
      await tester.tap(find.text('Bulanan'));
      await tester.pump();

      // Select lifetime plan
      await tester.ensureVisible(find.text('Selamanya'));
      await tester.tap(find.text('Selamanya'));
      await tester.pump();
    });
  });
}
