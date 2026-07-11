import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:league_points_app/data/season_document.dart';
import 'package:league_points_app/models/kart.dart';
import 'package:league_points_app/screens/kart_pick_order_screen.dart';

void main() {
  testWidgets('each division gets its own heaviest-first list for the selected week',
      (tester) async {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addDivision('Juniors');
    doc.addRacer(0, firstName: 'Light', lastName: 'Racer');
    doc.addRacer(0, firstName: 'Heavy', lastName: 'Racer');
    doc.addRacer(1, firstName: 'Mid', lastName: 'Racer');
    doc.updateWeeklyWeight(0, 0, 1, 120);
    doc.updateWeeklyWeight(0, 1, 1, 220);
    doc.updateWeeklyWeight(1, 0, 1, 170);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: doc,
        child: const MaterialApp(home: KartPickOrderScreen()),
      ),
    );

    final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    final names = rows.map((r) => (r.title as Text).data).toList();

    // Pro 1's own list is heaviest-first (Heavy, then Light), independent of
    // Juniors' list (Mid) -- each division's pick order is its own.
    expect(names, ['Heavy Racer', 'Light Racer', 'Mid Racer']);
  });

  testWidgets('changing a racer\'s weight re-sorts their division\'s list', (tester) async {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addRacer(0, firstName: 'A', lastName: 'Racer');
    doc.addRacer(0, firstName: 'B', lastName: 'Racer');
    doc.updateWeeklyWeight(0, 0, 1, 100);
    doc.updateWeeklyWeight(0, 1, 1, 150);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: doc,
        child: const MaterialApp(home: KartPickOrderScreen()),
      ),
    );

    var rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((rows.first.title as Text).data, 'B Racer');

    doc.updateWeeklyWeight(0, 0, 1, 999);
    await tester.pump();

    rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((rows.first.title as Text).data, 'A Racer');
  });

  testWidgets('selecting a racer and tapping a kart chip assigns that kart',
      (tester) async {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addRacer(0, firstName: 'Jane', lastName: 'Doe');
    doc.addKart(14, KartClass.pro);
    doc.addKart(75, KartClass.junior);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: doc,
        child: const MaterialApp(home: KartPickOrderScreen()),
      ),
    );

    // No racer selected yet -- no kart chips shown.
    expect(find.widgetWithText(FilterChip, 'Kart 14'), findsNothing);

    await tester.tap(find.text('Jane Doe'));
    await tester.pump();

    // Only the Pro kart shows (division is Pro by default); Junior kart is
    // filtered out of the pool for a Pro division.
    expect(find.widgetWithText(FilterChip, 'Kart 14'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Kart 75'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Kart 14'));
    await tester.pump();

    expect(doc.season.divisions[0].racers[0].weeklyResults[0].kartNumber, 14);
    expect(find.text('Pro 1 · Kart 14'), findsOneWidget);
  });

  testWidgets('a kart marked down for the week is disabled and labeled', (tester) async {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addRacer(0, firstName: 'Jane', lastName: 'Doe');
    doc.addKart(14, KartClass.pro);
    doc.setKartDownForWeek(14, 1, true);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: doc,
        child: const MaterialApp(home: KartPickOrderScreen()),
      ),
    );

    await tester.tap(find.text('Jane Doe'));
    await tester.pump();

    final chip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Kart 14 (down)'));
    expect(chip.onSelected, isNull);
  });

  testWidgets('a kart already taken in the same division is disabled for others',
      (tester) async {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addRacer(0, firstName: 'First', lastName: 'Racer');
    doc.addRacer(0, firstName: 'Second', lastName: 'Racer');
    doc.addKart(14, KartClass.pro);
    doc.updateWeeklyKartNumber(0, 0, 1, 14);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: doc,
        child: const MaterialApp(home: KartPickOrderScreen()),
      ),
    );

    await tester.tap(find.text('Second Racer'));
    await tester.pump();

    final chip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Kart 14 (taken)'));
    expect(chip.onSelected, isNull);
  });

  testWidgets('the same kart number can be assigned in two different divisions at once',
      (tester) async {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addDivision('Pro 2');
    doc.addRacer(0, firstName: 'First', lastName: 'Racer');
    doc.addRacer(1, firstName: 'Second', lastName: 'Racer');
    doc.addKart(14, KartClass.pro);
    doc.updateWeeklyKartNumber(0, 0, 1, 14);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: doc,
        child: const MaterialApp(home: KartPickOrderScreen()),
      ),
    );

    // Pro 2's racer isn't blocked by Pro 1's kart 14 -- different divisions
    // race at different times, so the same kart can go to both.
    await tester.tap(find.text('Second Racer'));
    await tester.pump();

    final chip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Kart 14'));
    expect(chip.onSelected, isNotNull);
  });
}
