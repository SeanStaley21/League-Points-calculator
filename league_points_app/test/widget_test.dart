import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:league_points_app/app.dart';
import 'package:league_points_app/data/season_document.dart';
import 'package:league_points_app/data/theme_controller.dart';

/// Wraps [LeaguePointsApp] with the providers it expects at runtime.
Widget _wrapApp(SeasonDocument doc) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: doc),
      ChangeNotifierProvider(create: (_) => ThemeController()),
    ],
    child: const LeaguePointsApp(),
  );
}

void main() {
  testWidgets('App launches into a blank season template', (tester) async {
    await tester.pumpWidget(_wrapApp(SeasonDocument()));

    expect(find.text('New Season'), findsOneWidget);
    expect(find.text('Untitled.lpts'), findsOneWidget);
  });

  testWidgets('File menu includes Auto Import', (tester) async {
    await tester.pumpWidget(_wrapApp(SeasonDocument()));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Auto Import...'), findsOneWidget);
  });

  testWidgets('Adding a division shows it as a standings card', (tester) async {
    final doc = SeasonDocument();
    await tester.pumpWidget(_wrapApp(doc));

    doc.addDivision('Pro 1');
    await tester.pump();

    expect(find.text('Pro 1'), findsWidgets);
  });
}
