import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:league_points_app/data/season_document.dart';
import 'package:league_points_app/widgets/weekly_standings_section.dart';

void main() {
  Widget wrap(SeasonDocument doc) => ChangeNotifierProvider.value(
        value: doc,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => WeeklyStandingsSection(
                  season: context.watch<SeasonDocument>().season),
            ),
          ),
        ),
      );

  testWidgets(
      'shows one Name/Finish column-group per division, alphabetical, for the selected week',
      (tester) async {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addDivision('Juniors');
    doc.addRacer(0, firstName: 'Zed', lastName: 'Racer');
    doc.addRacer(0, firstName: 'Amy', lastName: 'Racer');
    doc.addRacer(1, firstName: 'Mid', lastName: 'Racer');
    doc.updateWeeklyFinishPosition(0, 0, 1, 3); // Zed, week 1
    doc.updateWeeklyFinishPosition(0, 1, 1, 1); // Amy, week 1
    doc.updateWeeklyFinishPosition(0, 0, 2, 5); // Zed, week 2
    doc.updateWeeklyFinishPosition(1, 0, 1, 2); // Mid, week 1

    await tester.pumpWidget(wrap(doc));

    expect(find.text('Weekly Standings'), findsOneWidget);
    expect(find.text('Wk 1'), findsOneWidget);
    expect(find.text('Wk 2'), findsOneWidget);

    // Both division headers present, each with their own Name/Finish table.
    expect(find.text('Pro 1'), findsOneWidget);
    expect(find.text('Juniors'), findsOneWidget);
    expect(find.text('Name'), findsNWidgets(2));
    expect(find.text('Finish'), findsNWidgets(2));

    // Week 1 defaults selected: Pro 1 sorted alphabetically (Amy before Zed).
    final amyCenter = tester.getCenter(find.text('Amy Racer'));
    final zedCenter = tester.getCenter(find.text('Zed Racer'));
    expect(amyCenter.dy, lessThan(zedCenter.dy));

    List<String> finishFieldValues() => tester
        .widgetList<TextField>(find.byType(TextField))
        .map((w) => w.controller!.text)
        .toList();

    // Order in the tree: Pro 1 (Amy, Zed), then Juniors (Mid).
    expect(finishFieldValues(), ['1', '3', '2']);

    // Switch to week 2: Zed's finish updates, Amy and Mid have none recorded.
    await tester.tap(find.text('Wk 2'));
    await tester.pumpAndSettle();

    expect(finishFieldValues(), ['', '5', '']);
  });

  testWidgets('editing a Finish cell updates the underlying season document',
      (tester) async {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addRacer(0, firstName: 'Amy', lastName: 'Racer');

    await tester.pumpWidget(wrap(doc));

    await tester.enterText(find.byType(TextField).first, '4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // Commit happens on blur; tap elsewhere to unfocus the field.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(
        doc.season.divisions[0].racers[0].weeklyResults
            .firstWhere((r) => r.weekNumber == 1)
            .finishPosition,
        4);
  });

  testWidgets('shows each racer\'s assigned kart for the selected week, or "-" if none',
      (tester) async {
    final doc = SeasonDocument();
    doc.addDivision('Pro 1');
    doc.addRacer(0, firstName: 'Amy', lastName: 'Racer');
    doc.addRacer(0, firstName: 'Zed', lastName: 'Racer');
    doc.updateWeeklyKartNumber(0, 0, 1, 14);

    await tester.pumpWidget(wrap(doc));

    expect(find.text('Kart'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('renders nothing when there are no divisions', (tester) async {
    final doc = SeasonDocument();

    await tester.pumpWidget(wrap(doc));

    expect(find.text('Weekly Standings'), findsNothing);
  });
}
