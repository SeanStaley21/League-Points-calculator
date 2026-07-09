import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:league_points_app/app.dart';
import 'package:league_points_app/data/season_document.dart';

void main() {
  testWidgets('App launches into a blank season template', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SeasonDocument(),
        child: const LeaguePointsApp(),
      ),
    );

    expect(find.text('New Season'), findsOneWidget);
    expect(find.text('Auto Import'), findsOneWidget);
    expect(find.text('Untitled.lpts'), findsOneWidget);
  });

  testWidgets('Adding a division shows it as a tab', (tester) async {
    final doc = SeasonDocument();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: doc,
        child: const LeaguePointsApp(),
      ),
    );

    doc.addDivision('Pro 1');
    await tester.pump();

    expect(find.text('Pro 1'), findsWidgets);
  });
}
