import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cookbuk/config/theme_presets.dart';

class ThemeController extends ChangeNotifier {
  static const _preferenceKey = 'cookbuk_theme_id';
  static const _themeModePreferenceKey = 'cookbuk_theme_mode';

  String _themeId = CookbukThemes.defaultId;
  ThemeMode _themeMode = ThemeMode.system;

  String get themeId => _themeId;
  ThemeMode get themeMode => _themeMode;

  CookbukThemePreset get preset => CookbukThemes.byId(_themeId);

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedThemeId = preferences.getString(_preferenceKey);
    if (savedThemeId != null) {
      _themeId = CookbukThemes.byId(savedThemeId).id;
    }
    _themeMode = _themeModeFromName(
      preferences.getString(_themeModePreferenceKey),
    );
  }

  Future<void> setTheme(String themeId) async {
    final nextThemeId = CookbukThemes.byId(themeId).id;
    if (nextThemeId == _themeId) return;

    _themeId = nextThemeId;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, nextThemeId);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;

    _themeMode = mode;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModePreferenceKey, mode.name);
  }

  ThemeMode _themeModeFromName(String? name) {
    return switch (name) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

final themeController = ThemeController();
