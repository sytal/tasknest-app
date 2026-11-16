import 'package:flutter/material.dart';

/// Single source of truth for brand colours (from the TaskNest logo:
/// navy bird, orange/amber nest, green leaf, warm cream background).
class AppColors {
  AppColors._();

  // Brand tokens (light / dark pairs resolved in the theme).
  static const navy = Color(0xFF0C2454);
  static const navyTint = Color(0xFF8FB0FF); // navy on dark surfaces
  static const navyDeep = Color(0xFF0C243C);
  static const navyDark = Color(0xFF0B1626); // dark scaffold
  static const orange = Color(0xFFF58A07);
  static const orangeDark = Color(0xFFFFA533);
  static const amber = Color(0xFFFCB40C);
  static const amberDark = Color(0xFFFFC84A);
  static const leaf = Color(0xFF5BA82E);
  static const leafDark = Color(0xFF7CC653);
  static const cream = Color(0xFFFFFBEF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF122338);
  static const outline = Color(0xFFE6DFCB);
  static const outlineDark = Color(0xFF26384F);
  static const danger = Color(0xFFD64545);
  static const dangerDark = Color(0xFFFF7A7A);

  // Data colours (avatars, labels) derived from the brand family.
  static const onDarkSurface = Color(0xFFEAF0FA);
  static const surfaceDarkHigh = Color(0xFF1B3050);
  static const fieldDark = Color(0xFF1C2E52);
  static const avatarPalette = [
    navy,
    Color(0xFFC96A00),
    Color(0xFF3F7F1F),
    Color(0xFF1B3A7A),
    Color(0xFF8A5A00),
    Color(0xFF2E6F73),
  ];
  static const labelPalette = <String, Color>{
    'red': danger,
    'orange': orange,
    'amber': Color(0xFFD9A400),
    'green': leaf,
    'teal': Color(0xFF2E8F8F),
    'blue': Color(0xFF3E63DD),
    'purple': Color(0xFF8E4EC6),
    'pink': Color(0xFFD6409F),
  };
  static int avatarIndex(String seed) =>
      seed.codeUnits.fold<int>(0, (a, b) => a + b) % avatarPalette.length;
  static const labelFallback = Color(0xFF8B8D98);

  // Neutral text.
  static const textPrimary = Color(0xFF0C243C);
  static const textSecondary = Color(0xFF4B5A70);

  // Legacy aliases kept so existing widgets pick up the new palette.
  static const navy900 = navyDark;
  static const navy800 = Color(0xFF122338);
  static const navy700 = navy;
  static const navy600 = Color(0xFF1B3A7A);
  static const navy500 = Color(0xFF34507F);
  static const navy200 = Color(0xFFB9C7DD);
  static const navy100 = Color(0xFFE2E8F2);
  static const cream50 = cream;
  static const cream100 = Color(0xFFFFFBEF);
  static const cream200 = Color(0xFFF6F0DE);
  static const cream300 = outline;
  static const textDarkPrimary = textPrimary;
  static const textDarkSecondary = textSecondary;
  static const success = leaf;
  static const warning = amber;
  static const error = danger;
  static const info = navy;
}
