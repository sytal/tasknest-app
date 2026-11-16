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
