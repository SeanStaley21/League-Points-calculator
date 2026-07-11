import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/season_document.dart';
import 'data/theme_controller.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SeasonDocument()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: const LeaguePointsApp(),
    ),
  );
}
