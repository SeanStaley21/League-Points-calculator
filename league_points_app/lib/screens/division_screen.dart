import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/points_calculator.dart';
import '../data/season_document.dart';
import '../models/racer.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/week_position_cell.dart';

/// Editable weekly-points table for one division, addressed by its index
/// in Season.divisions (stable for the lifetime of a single screen build).
class DivisionScreen extends StatelessWidget {
  const DivisionScreen({super.key, required this.divisionIndex});

  final int divisionIndex;

  static String _formatWeight(double weight) => weight == weight.roundToDouble()
      ? weight.toInt().toString()
      : weight.toString();

  Future<void> _showRacerDialog(
    BuildContext context, {
    String initialFirstName = '',
    String initialLastName = '',
    String initialWeight = '',
    String initialImportName = '',
    String initialPhone = '',
    String initialEmail = '',
    required void Function(String firstName, String lastName, double weight,
            String importName, String phone, String email)
        onSubmit,
  }) async {
    final firstNameController = TextEditingController(text: initialFirstName);
    final lastNameController = TextEditingController(text: initialLastName);
    final weightController = TextEditingController(text: initialWeight);
    final importNameController = TextEditingController(text: initialImportName);
    final phoneController = TextEditingController(text: initialPhone);
    final emailController = TextEditingController(text: initialEmail);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialFirstName.isEmpty ? 'Add Racer' : 'Edit Racer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(labelText: 'First name'),
              autofocus: true,
            ),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(labelText: 'Last name'),
            ),
            TextField(
              controller: weightController,
              decoration: const InputDecoration(labelText: 'Weight (lbs)', hintText: '0'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
            ),
            TextField(
              controller: importNameController,
              decoration: const InputDecoration(
                labelText: 'Import name (optional)',
                hintText: 'For Auto-Import to work',
              ),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => Navigator.of(context).pop(true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && firstNameController.text.trim().isNotEmpty) {
      onSubmit(
        firstNameController.text.trim(),
        lastNameController.text.trim(),
        double.tryParse(weightController.text.trim()) ?? 0,
        importNameController.text.trim(),
        phoneController.text.trim(),
        emailController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = context.watch<SeasonDocument>();
    final division = doc.season.divisions[divisionIndex];
    final weekCount = doc.season.weekCount;
    final scoredPositions = doc.season.scoredPositions;
    final racers = List.of(division.racers)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add Racer'),
              onPressed: () => _showRacerDialog(
                context,
                onSubmit: (firstName, lastName, weight, importName, phone, email) {
                  context.read<SeasonDocument>().addRacer(
                        divisionIndex,
                        firstName: firstName,
                        lastName: lastName,
                        weight: weight,
                        importName: importName.isEmpty ? null : importName,
                        phone: phone.isEmpty ? null : phone,
                        email: email.isEmpty ? null : email,
                      );
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: racers.isEmpty
              ? const Center(child: Text('No racers yet. Add one to get started.'))
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 64,
                      columns: [
                        const DataColumn(label: Text('Racer')),
                        for (var week = 1; week <= weekCount; week++)
                          DataColumn(label: Text('Wk $week')),
                        const DataColumn(label: Text('Total')),
                        const DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (var racerIndex = 0; racerIndex < racers.length; racerIndex++)
                          _buildRow(context, racerIndex, racers[racerIndex], weekCount,
                              scoredPositions),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  DataRow _buildRow(BuildContext context, int racerIndex, Racer racer, int weekCount,
      int scoredPositions) {
    final doc = context.read<SeasonDocument>();
    return DataRow(cells: [
      DataCell(Text(racer.fullName)),
      for (var week = 1; week <= weekCount; week++)
        DataCell(WeekPositionCell(
          finishPosition: racer.weeklyResults
              .firstWhere((r) => r.weekNumber == week)
              .finishPosition,
          points: pointsForResult(
              racer.weeklyResults.firstWhere((r) => r.weekNumber == week),
              scoredPositions),
          onChanged: (position) => doc.updateWeeklyFinishPosition(
              divisionIndex, racerIndex, week, position),
        )),
      DataCell(Text(
        '${racer.totalPoints(scoredPositions)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      )),
      DataCell(PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (action) async {
          if (action == 'edit') {
            await _showRacerDialog(
              context,
              initialFirstName: racer.firstName,
              initialLastName: racer.lastName,
              initialWeight: _formatWeight(racer.weight),
              initialImportName: racer.importName ?? '',
              initialPhone: racer.phone ?? '',
              initialEmail: racer.email ?? '',
              onSubmit: (firstName, lastName, weight, importName, phone, email) {
                doc.updateRacerInfo(
                  divisionIndex,
                  racerIndex,
                  firstName: firstName,
                  lastName: lastName,
                  weight: weight,
                  importName: importName.isEmpty ? null : importName,
                  clearImportName: importName.isEmpty,
                  phone: phone.isEmpty ? null : phone,
                  clearPhone: phone.isEmpty,
                  email: email.isEmpty ? null : email,
                  clearEmail: email.isEmpty,
                );
              },
            );
          } else if (action == 'remove') {
            final confirmed = await showConfirmDialog(
              context,
              title: 'Remove racer',
              message: 'Remove ${racer.fullName} and all of their weekly results?',
              confirmLabel: 'Remove',
              destructive: true,
            );
            if (confirmed) doc.removeRacer(divisionIndex, racerIndex);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'remove', child: Text('Remove')),
        ],
      )),
    ]);
  }
}
