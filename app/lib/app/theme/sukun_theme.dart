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
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: SukunColors.paleBlue,
        surfaceContainer: SukunColors.mist,
        outline: SukunColors.border,
        outlineVariant: SukunColors.border,
        error: SukunColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: SukunColors.canvas,
    );
    final textTheme = SukunTypography.englishTextTheme(base.textTheme).apply(
      bodyColor: SukunColors.nightNavy,
      displayColor: SukunColors.nightNavy,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: SukunColors.canvas,
        foregroundColor: SukunColors.nightNavy,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        toolbarHeight: 68,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: SukunColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0.6,
        shadowColor: SukunColors.nightNavy.withValues(alpha: 0.10),
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: Color(0x110D2B45)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SukunColors.sukunBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 54),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SukunColors.deepTide,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: SukunColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SukunColors.deepTide,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SukunColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: SukunColors.muted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: SukunColors.muted),
        helperStyle: textTheme.bodySmall?.copyWith(color: SukunColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SukunColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SukunColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SukunColors.sukunBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: SukunColors.error),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SukunColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: SukunColors.paleBlue,
        selectedColor: SukunColors.softBlue,
        side: const BorderSide(color: SukunColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: SukunColors.sukunBlue,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SukunColors.sukunBlue,
        linearTrackColor: SukunColors.softBlue,
        linearMinHeight: 7,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SukunColors.nightNavy,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
