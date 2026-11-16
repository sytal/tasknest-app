import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TaskNest design system: a premium "navy + cream" palette intended to read
/// as a polished internal enterprise tool rather than a generic Material
/// demo app. Light mode uses warm cream surfaces with deep navy accents;
/// dark mode uses deep navy surfaces with cream text and navy-tinted
/// elevation, rather than a naive inversion.
class AppColors {
  AppColors._();

  // Brand navy.
  static const navy900 = Color(0xFF0F1F3D); // deepest navy, dark bg
  static const navy800 = Color(0xFF16284A);
  static const navy700 = Color(0xFF1B2A4A); // primary brand navy
  static const navy600 = Color(0xFF263C66);
  static const navy500 = Color(0xFF34507F);
  static const navy200 = Color(0xFFB9C4D6);
  static const navy100 = Color(0xFFE2E7F0);

  // Cream / warm neutrals.
  static const cream50 = Color(0xFFFAF6EE); // light bg
  static const cream100 = Color(0xFFF8F5EF); // card surface light
  static const cream200 = Color(0xFFF1ECE1);
  static const cream300 = Color(0xFFE6DFCF);

  // Warm text neutrals.
  static const textDarkPrimary = Color(0xFF231F16);
  static const textDarkSecondary = Color(0xFF5B5748);

  // Semantic accents (kept warm/muted to fit the elegant palette).
  static const success = Color(0xFF2F9E6E);
  static const warning = Color(0xFFC98A1F);
  static const error = Color(0xFFC0462B);
  static const info = Color(0xFF3D6FB0);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? const ColorScheme.dark(
            brightness: Brightness.dark,
            primary: AppColors.cream100,
            onPrimary: AppColors.navy900,
            secondary: AppColors.navy200,
            onSecondary: AppColors.navy900,
            surface: Color(0xFF14233F), // elevated navy card
            onSurface: AppColors.cream100,
            surfaceContainerHighest: Color(0xFF1C2E52),
            error: Color(0xFFE38671),
            onError: AppColors.navy900,
            outline: Color(0xFF3C4E72),
          )
        : const ColorScheme.light(
            brightness: Brightness.light,
            primary: AppColors.navy700,
            onPrimary: AppColors.cream50,
            secondary: AppColors.navy500,
            onSecondary: Colors.white,
            surface: AppColors.cream100,
            onSurface: AppColors.textDarkPrimary,
            surfaceContainerHighest: AppColors.cream200,
            error: AppColors.error,
            onError: Colors.white,
            outline: Color(0xFFCFC6B2),
          );

    final scaffoldBg = isDark ? AppColors.navy900 : AppColors.cream50;
    final appBarBg = isDark ? AppColors.navy800 : AppColors.navy700;
    const appBarFg = AppColors.cream50;

    final baseTextTheme = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    final textTheme = baseTextTheme
        .copyWith(
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          headlineSmall: baseTextTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            color: isDark ? AppColors.navy200 : AppColors.textDarkSecondary,
          ),
          bodySmall: baseTextTheme.bodySmall?.copyWith(
            color: isDark ? AppColors.navy200 : AppColors.textDarkSecondary,
          ),
        )
        .apply(
          bodyColor: isDark ? AppColors.cream100 : AppColors.textDarkPrimary,
          displayColor: isDark ? AppColors.cream100 : AppColors.textDarkPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      dividerColor: colorScheme.outline.withValues(alpha: 0.3),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: appBarFg),
        titleTextStyle: GoogleFonts.inter(
          color: appBarFg,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF17294B) : Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? const Color(0xFF2B3E64) : AppColors.cream300,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.7)),
        selectedColor: colorScheme.primary.withValues(
          alpha: isDark ? 0.35 : 0.2,
        ),
        checkmarkColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF1C2E52)
            : AppColors.cream200.withValues(alpha: 0.6),
        hintStyle: TextStyle(
          color: isDark ? AppColors.navy200 : AppColors.textDarkSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.cream100 : AppColors.navy700,
          foregroundColor: isDark ? AppColors.navy900 : AppColors.cream50,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.cream100 : AppColors.navy700,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.cream100 : AppColors.navy700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? AppColors.cream100 : AppColors.navy700,
        foregroundColor: isDark ? AppColors.navy900 : AppColors.cream50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF17294B) : AppColors.cream100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.cream100 : AppColors.navy700,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.navy900 : AppColors.cream50,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.3),
        space: 1,
      ),
    );
  }
}
