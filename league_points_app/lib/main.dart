import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/season_document.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SeasonDocument(),
      child: const LeaguePointsApp(),
    ),
  );
}
