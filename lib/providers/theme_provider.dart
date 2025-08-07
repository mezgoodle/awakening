import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  static const String _themeKey = 'theme_mode';

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.dark.index;
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  void _saveTheme(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_themeKey, themeMode.index);
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _saveTheme(_themeMode);
    notifyListeners();
  }
}
