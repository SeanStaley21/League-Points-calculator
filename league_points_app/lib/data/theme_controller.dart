import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A named color choice offered in the App Appearance dialog.
class AppColorOption {
  const AppColorOption(this.name, this.color);
  final String name;
  final Color color;
}

const List<AppColorOption> appColorOptions = [
  AppColorOption('Deep Orange', Colors.deepOrange),
  AppColorOption('Blue', Colors.blue),
  AppColorOption('Indigo', Colors.indigo),
  AppColorOption('Teal', Colors.teal),
  AppColorOption('Green', Colors.green),
  AppColorOption('Purple', Colors.purple),
  AppColorOption('Pink', Colors.pink),
  AppColorOption('Red', Colors.red),
  AppColorOption('Amber', Colors.amber),
];

const _prefsKeySeedColor = 'appearance.seedColor';
const _prefsKeyThemeMode = 'appearance.themeMode';

/// Holds the app-wide color seed and light/dark/system mode, persisted so
/// the choice survives restarts. Starts with defaults (deep orange, system)
/// and swaps to the saved values once [SharedPreferences] finishes loading.
class ThemeController extends ChangeNotifier {
  ThemeController() {
    _load();
  }

  Color _seedColor = Colors.deepOrange;
  Color get seedColor => _seedColor;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final colorValue = prefs.getInt(_prefsKeySeedColor);
    if (colorValue != null) _seedColor = Color(colorValue);

    final modeName = prefs.getString(_prefsKeyThemeMode);
    if (modeName != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => ThemeMode.system,
      );
    }

    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeySeedColor, color.toARGB32());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyThemeMode, mode.name);
  }
}
