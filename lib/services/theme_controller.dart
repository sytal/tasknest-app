import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's light/dark/system choice and persists it.
class ThemeController extends ChangeNotifier {
  static const _key = 'tasknest_theme_mode';
  ThemeMode mode = ThemeMode.system;

  Future<void> load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_key);
      mode = ThemeMode.values.firstWhere(
        (m) => m.name == v,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_key, m.name);
    } catch (_) {}
  }
}
