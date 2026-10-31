import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tautin/shared/widgets/tauti_badge.dart';
import 'package:tautin/shared/widgets/tauti_mascot.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('TautiBadge', () {
    testWidgets('renders both colourways without overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TautiBadge(size: 40),
              SizedBox(width: 12),
              TautiBadge(size: 40, inverted: true),
            ],
          ),
        ),
      );

      expect(find.byType(TautiBadge), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('TautiMascot', () {
    testWidgets('renders every mood in the mockup', (
      WidgetTester tester,
    ) async {
      for (final TautiMood mood in TautiMood.values) {
        await tester.pumpWidget(
          _wrap(TautiMascot(mood: mood, width: 140)),
        );
        expect(
          find.byType(TautiMascot),
          findsOneWidget,
          reason: 'mood $mood should render',
        );
        expect(tester.takeException(), isNull, reason: 'mood $mood threw');
      }
    });

    testWidgets('height follows the 200:250 viewBox ratio', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const TautiMascot(width: 100)));

      final Size size = tester.getSize(find.byType(TautiMascot));
      expect(size.width, 100);
      expect(size.height, 125);
    });

    testWidgets('static mode never starts a ticker', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const TautiMascot(mood: TautiMood.cheer, animate: false)),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('animated moods keep ticking without throwing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const TautiMascot(mood: TautiMood.cheer, width: 160)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sleep pushes the floating z animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const TautiMascot(mood: TautiMood.sleep, width: 140)),
      );
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 1200));
      expect(tester.takeException(), isNull);
    });
  });

  group('TautiOutfit', () {
    test('levels match the design brief', () {
      expect(TautiOutfit.none.level, 0);
      expect(TautiOutfit.curator.level, 5);
      expect(TautiOutfit.master.level, 10);
      expect(TautiOutfit.legend.level, 20);
    });

    testWidgets('every outfit can be combined with every mood', (
      WidgetTester tester,
    ) async {
      for (final TautiOutfit outfit in TautiOutfit.values) {
        for (final TautiMood mood in TautiMood.values) {
          await tester.pumpWidget(
            _wrap(TautiMascot(mood: mood, outfit: outfit, width: 120)),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: '$outfit/$mood threw');
        }
      }
    });

    testWidgets('switching mood and outfit restarts the animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const TautiMascot(mood: TautiMood.idle, width: 120)),
      );
      await tester.pumpWidget(
        _wrap(
          const TautiMascot(
            mood: TautiMood.cheer,
            outfit: TautiOutfit.legend,
            width: 120,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });
  });
}
