import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/theme_controller.dart';
import '../widgets/app_appearance_controls.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _modeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  String _colorLabel(Color color) {
    for (final option in appColorOptions) {
      if (option.color.toARGB32() == color.toARGB32()) return option.name;
    }
    return 'Custom';
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ExpansionTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('App Appearance'),
            subtitle: Text(
                '${_modeLabel(themeController.themeMode)} · ${_colorLabel(themeController.seedColor)}'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: const [AppAppearanceControls()],
          ),
        ],
      ),
    );
  }
}
