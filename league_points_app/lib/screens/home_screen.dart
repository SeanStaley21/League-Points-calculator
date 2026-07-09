import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/season_document.dart';
import '../widgets/app_menu_bar.dart';
import '../widgets/standings_snapshot_card.dart';
import 'auto_import_screen.dart';
import 'division_screen.dart';
import 'season_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doc = context.watch<SeasonDocument>();
    final season = doc.season;
    final dateFormat = DateFormat.yMMMd();
    // +1 for the fixed "Auto Import" tab alongside one tab per division.
    final tabCount = season.divisions.length + 1;

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        appBar: const AppMenuBar(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(season.name, style: Theme.of(context).textTheme.headlineSmall),
                        Text(
                          season.endDate == null
                              ? 'Starts ${dateFormat.format(season.startDate)}'
                              : '${dateFormat.format(season.startDate)} – ${dateFormat.format(season.endDate!)}',
                        ),
                        Text(
                            '${season.divisions.length} divisions • ${season.weekCount} weeks'),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Season Setup',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SeasonSetupScreen()),
                    ),
                  ),
                ],
              ),
            ),
            if (season.divisions.isNotEmpty)
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final division in season.divisions)
                      SizedBox(
                        width: 200,
                        child: StandingsSnapshotCard(
                          division: division,
                          scoredPositions: season.scoredPositions,
                        ),
                      ),
                  ],
                ),
              ),
            TabBar(
              isScrollable: true,
              tabs: [
                for (final division in season.divisions) Tab(text: division.name),
                const Tab(text: 'Auto Import'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (var i = 0; i < season.divisions.length; i++)
                    DivisionScreen(divisionIndex: i),
                  const AutoImportScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
