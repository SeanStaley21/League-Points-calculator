import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/season_document.dart';
import '../models/kart.dart';
import '../widgets/confirm_dialog.dart';

class SeasonSetupScreen extends StatefulWidget {
  const SeasonSetupScreen({super.key});

  @override
  State<SeasonSetupScreen> createState() => _SeasonSetupScreenState();
}

class _SeasonSetupScreenState extends State<SeasonSetupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _weekCountController;
  late final TextEditingController _scoredPositionsController;
  late DateTime _startDate;
  DateTime? _endDate;
  final _dateFormat = DateFormat.yMMMd();
  final _newDivisionController = TextEditingController();
  KartClass _newDivisionKartClass = KartClass.pro;

  @override
  void initState() {
    super.initState();
    final season = context.read<SeasonDocument>().season;
    _nameController = TextEditingController(text: season.name);
    _weekCountController = TextEditingController(text: '${season.weekCount}');
    _scoredPositionsController =
        TextEditingController(text: '${season.scoredPositions}');
    _startDate = season.startDate;
    _endDate = season.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weekCountController.dispose();
    _scoredPositionsController.dispose();
    _newDivisionController.dispose();
    super.dispose();
  }

  void _addDivision() {
    final name = _newDivisionController.text.trim();
    if (name.isEmpty) return;
    context.read<SeasonDocument>().addDivision(name, kartClass: _newDivisionKartClass);
    _newDivisionController.clear();
  }

  void _saveSeasonInfo() {
    final weekCount = int.tryParse(_weekCountController.text);
    final scoredPositions = int.tryParse(_scoredPositionsController.text);
    context.read<SeasonDocument>().updateSeasonInfo(
          name: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          weekCount: weekCount,
          scoredPositions: scoredPositions,
        );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final doc = context.watch<SeasonDocument>();
    final divisions = doc.season.divisions;

    return Scaffold(
      appBar: AppBar(title: const Text('Season Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Season name'),
            onSubmitted: (_) => _saveSeasonInfo(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start date'),
                  subtitle: Text(_dateFormat.format(_startDate)),
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End date'),
                  subtitle: Text(_endDate == null
                      ? 'Not set'
                      : _dateFormat.format(_endDate!)),
                  onTap: () => _pickDate(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weekCountController,
            decoration: const InputDecoration(labelText: 'Number of weeks'),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _saveSeasonInfo(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _scoredPositionsController,
            decoration: const InputDecoration(
              labelText: 'Scored positions',
              helperText:
                  'How many finish positions score points (e.g. 13 covers '
                  '1st-13th). Increase this if a division has more racers '
                  'than that.',
              helperMaxLines: 2,
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _saveSeasonInfo(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {
                _saveSeasonInfo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Season info updated')),
                );
              },
              child: const Text('Save season info'),
            ),
          ),
          const Divider(height: 32),
          Text('Divisions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < divisions.length; i++)
            ListTile(
              title: Text(divisions[i].name),
              subtitle: Text('${divisions[i].racers.length} racers'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<KartClass>(
                    value: divisions[i].kartClass,
                    items: const [
                      DropdownMenuItem(value: KartClass.pro, child: Text('Pro karts')),
                      DropdownMenuItem(value: KartClass.junior, child: Text('Junior karts')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        context.read<SeasonDocument>().updateDivisionClass(i, value);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Rename',
                    onPressed: () => _renameDivision(context, i, divisions[i].name),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove',
                    onPressed: () => _removeDivision(context, i, divisions[i].name),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newDivisionController,
                  decoration: const InputDecoration(labelText: 'New division name'),
                  onSubmitted: (_) => _addDivision(),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<KartClass>(
                value: _newDivisionKartClass,
                items: const [
                  DropdownMenuItem(value: KartClass.pro, child: Text('Pro karts')),
                  DropdownMenuItem(value: KartClass.junior, child: Text('Junior karts')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _newDivisionKartClass = value);
                },
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addDivision,
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _renameDivision(BuildContext context, int index, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename division'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && context.mounted) {
      context.read<SeasonDocument>().renameDivision(index, newName);
    }
  }

  Future<void> _removeDivision(BuildContext context, int index, String name) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove division',
      message: 'Remove "$name" and all of its racers/results?',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<SeasonDocument>().removeDivision(index);
    }
  }
}
