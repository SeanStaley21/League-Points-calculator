import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/season_document.dart';
import '../models/division.dart';
import '../models/racer.dart';

/// Read-only directory of every racer in the season and their contact info,
/// grouped by division, with a search box to filter by name/phone/email.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Racer racer) {
    if (_query.isEmpty) return true;
    return racer.fullName.toLowerCase().contains(_query) ||
        (racer.phone ?? '').toLowerCase().contains(_query) ||
        (racer.email ?? '').toLowerCase().contains(_query);
  }

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $label'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final season = context.watch<SeasonDocument>().season;
    final divisions = List<Division>.of(season.divisions)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final groups = <MapEntry<Division, List<Racer>>>[];
    for (final division in divisions) {
      final racers = List<Racer>.of(division.racers)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final filtered = racers.where(_matches).toList();
      if (filtered.isNotEmpty) groups.add(MapEntry(division, filtered));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search racers',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? Center(
                    child: Text(
                      season.divisions.isEmpty
                          ? 'No divisions yet. Add one in Season Setup.'
                          : 'No racers match your search.',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      for (final group in groups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            group.key.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        for (final racer in group.value) _ContactTile(racer: racer, onCopy: _copy),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.racer, required this.onCopy});

  final Racer racer;
  final void Function(BuildContext context, String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    final hasPhone = (racer.phone ?? '').isNotEmpty;
    final hasEmail = (racer.email ?? '').isNotEmpty;

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(racer.fullName),
      subtitle: !hasPhone && !hasEmail
          ? const Text('No contact info on file')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPhone) Text(racer.phone!),
                if (hasEmail) Text(racer.email!),
              ],
            ),
      isThreeLine: hasPhone && hasEmail,
      trailing: !hasPhone && !hasEmail
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPhone)
                  IconButton(
                    icon: const Icon(Icons.phone_outlined),
                    tooltip: 'Copy phone',
                    onPressed: () => onCopy(context, 'phone', racer.phone!),
                  ),
                if (hasEmail)
                  IconButton(
                    icon: const Icon(Icons.email_outlined),
                    tooltip: 'Copy email',
                    onPressed: () => onCopy(context, 'email', racer.email!),
                  ),
              ],
            ),
    );
  }
}
