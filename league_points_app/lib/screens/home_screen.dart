import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/season_document.dart';
import '../models/division.dart';
import '../widgets/app_menu_bar.dart';
import '../widgets/standings_snapshot_card.dart';
import 'division_screen.dart';
import 'kart_pick_order_screen.dart';
import 'season_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openDivision(BuildContext context, int divisionIndex, Division division) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(division.name)),
          body: DivisionScreen(divisionIndex: divisionIndex),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = context.watch<SeasonDocument>();
    final season = doc.season;
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
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
                  icon: const Icon(Icons.scale_outlined),
                  tooltip: 'Kart Pick Order',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KartPickOrderScreen()),
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
          Expanded(
            child: season.divisions.isEmpty
                ? const Center(child: Text('No divisions yet. Add one in Season Setup.'))
                : GridView(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisExtent: 110,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    children: [
                      for (var i = 0; i < season.divisions.length; i++)
                        StandingsSnapshotCard(
                          division: season.divisions[i],
                          scoredPositions: season.scoredPositions,
                          onTap: () => _openDivision(context, i, season.divisions[i]),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
