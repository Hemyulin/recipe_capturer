import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cookbuk/config/theme_presets.dart';

class ThemeController extends ChangeNotifier {
  static const _preferenceKey = 'cookbuk_theme_id';

  String _themeId = CookbukThemes.defaultId;

  String get themeId => _themeId;

  CookbukThemePreset get preset => CookbukThemes.byId(_themeId);

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedThemeId = preferences.getString(_preferenceKey);
    if (savedThemeId == null) return;
    _themeId = CookbukThemes.byId(savedThemeId).id;
  }

  Future<void> setTheme(String themeId) async {
    final nextThemeId = CookbukThemes.byId(themeId).id;
    if (nextThemeId == _themeId) return;

    _themeId = nextThemeId;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, nextThemeId);
  }
}

final themeController = ThemeController();
