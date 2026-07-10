import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:league_points_app/data/season_document.dart';
import 'package:league_points_app/screens/kart_pick_order_screen.dart';

void main() {
  testWidgets('lists racers across divisions heaviest-first for the selected week',
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
    final divisions = rows.map((r) => (r.subtitle as Text).data).toList();

    // Heaviest (220) first, then 170, then lightest (120).
    expect(names, ['Heavy Racer', 'Mid Racer', 'Light Racer']);
    expect(divisions, ['Pro 1', 'Juniors', 'Pro 1']);
  });

  testWidgets('changing a racer\'s weight re-sorts the list', (tester) async {
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
}
