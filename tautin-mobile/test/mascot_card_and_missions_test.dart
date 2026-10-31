import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tautin/features/gamification/domain/gamification_summary.dart';
import 'package:tautin/features/gamification/presentation/widgets/missions_modal_sheet.dart';
import 'package:tautin/features/gamification/presentation/widgets/tauti_mascot_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

void main() {
  group('TautiMascotCard', () {
    testWidgets('renders level pill, title, XP counter and speech bubble', (
      WidgetTester tester,
    ) async {
      final GamificationSummary summary = GamificationSummary.initial();

      await tester.pumpWidget(
        _wrap(
          TautiMascotCard(
            summary: summary,
          ),
        ),
      );

      expect(find.text('Lv 3'), findsOneWidget);
      expect(find.text('Pemungut Tautan'), findsOneWidget);
      expect(find.text('40 / 100 XP'), findsOneWidget);
      expect(find.text('Misi'), findsOneWidget);
      expect(find.text('Streak 5 hari! Terus semangat! 💪'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap on card triggers poke mood and resets to idle', (
      WidgetTester tester,
    ) async {
      final GamificationSummary summary = GamificationSummary.initial();

      await tester.pumpWidget(
        _wrap(
          TautiMascotCard(summary: summary),
        ),
      );

      // Tap card body to poke
      await tester.tap(find.byType(TautiMascotCard));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Advance past poke timer
      await tester.pump(const Duration(milliseconds: 1300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Misi calls callback', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          TautiMascotCard(
            summary: GamificationSummary.initial(),
            onMisiTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Misi'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('MissionsModalSheet', () {
    testWidgets('renders missions list and streak badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MissionsModalSheet(
            summary: GamificationSummary.initial(),
          ),
        ),
      );

      expect(find.text('Misi & Progres'), findsOneWidget);
      expect(find.text('5 hari'), findsOneWidget);
      expect(find.text('Simpan 3 tautan'), findsOneWidget);
      expect(find.text('Baca 1 tautan'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('0/1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
