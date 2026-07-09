import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class LeaguePointsApp extends StatelessWidget {
  const LeaguePointsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'League Points Calculator',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange)),
      home: const HomeScreen(),
    );
  }
}
