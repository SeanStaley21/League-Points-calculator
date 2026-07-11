import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/theme_controller.dart';
import 'screens/home_screen.dart';

class LeaguePointsApp extends StatelessWidget {
  const LeaguePointsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      title: 'League Points Calculator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeController.seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeController.seedColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: themeController.themeMode,
      home: const HomeScreen(),
    );
  }
}
