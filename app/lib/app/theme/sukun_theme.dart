import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';

abstract final class SukunTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: SukunColors.sukunBlue,
        onPrimary: Colors.white,
        secondary: SukunColors.deepTide,
        onSecondary: Colors.white,
        surface: SukunColors.surface,
        onSurface: SukunColors.nightNavy,
        error: SukunColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: SukunColors.mist,
    );
    final textTheme = SukunTypography.englishTextTheme(base.textTheme).apply(
      bodyColor: SukunColors.nightNavy,
      displayColor: SukunColors.nightNavy,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: SukunColors.surface,
        foregroundColor: SukunColors.nightNavy,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: SukunColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SukunColors.sukunBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SukunColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SukunColors.sukunBlue, width: 2),
        ),
      ),
    );
  }
}
