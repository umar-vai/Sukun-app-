import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/app/theme/bengali_font_settings.dart';
import 'package:sukun_life/app/theme/app_display_settings.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';
import 'package:sukun_life/app/theme/sukun_palette_theme.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';

abstract final class SukunTheme {
  static ThemeData light({
    BengaliFontChoice bengaliFont = BengaliFontChoice.liAdorNoirrit,
    double bengaliScale = 1.0,
    SukunAccentPalette accentPalette = SukunAccentPalette.sukunBlue,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: SukunColors.sukunBlue,
        onPrimary: SukunColors.nightNavy,
        primaryContainer: SukunColors.softBlue,
        onPrimaryContainer: SukunColors.deepTide,
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
    final textTheme =
        SukunTypography.withBengaliFallback(
          SukunTypography.englishTextTheme(base.textTheme),
          bengaliFont,
        ).apply(
          fontSizeFactor: AppDisplaySettings.validBengaliScale(bengaliScale),
          bodyColor: SukunColors.nightNavy,
          displayColor: SukunColors.nightNavy,
        );

    final normalTheme = base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: SukunColors.canvas,
        foregroundColor: SukunColors.nightNavy,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: SukunSpace.page,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 19,
        ),
      ),
      cardTheme: CardThemeData(
        color: SukunColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: SukunColors.deepTide.withValues(alpha: 0.10),
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(SukunRadius.card)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Deep Tide keeps white button text at WCAG AA contrast.
          backgroundColor: SukunColors.deepTide,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SukunRadius.control),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SukunColors.deepTide,
          backgroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: SukunColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SukunRadius.control),
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
          borderRadius: BorderRadius.circular(SukunRadius.control),
          borderSide: BorderSide(color: SukunColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SukunRadius.control),
          borderSide: BorderSide(color: SukunColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SukunRadius.control),
          borderSide: BorderSide(color: SukunColors.deepTide, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SukunRadius.control),
          borderSide: const BorderSide(color: SukunColors.error),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: SukunColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: SukunColors.mist,
        side: BorderSide(color: SukunColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SukunRadius.chip),
        ),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(SukunRadius.hero)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SukunRadius.sheet),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: SukunColors.deepTide,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(SukunRadius.tile)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: SukunColors.deepTide,
        contentPadding: EdgeInsets.symmetric(horizontal: SukunSpace.lg),
        titleTextStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: SukunColors.muted,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? SukunColors.deepTide
              : null,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? SukunColors.mist
                : Colors.white,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? SukunColors.deepTide
                : SukunColors.muted,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: SukunColors.border)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(SukunRadius.control),
              ),
            ),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: SukunColors.deepTide,
        unselectedLabelColor: SukunColors.muted,
        labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: SukunColors.sukunBlue, width: 3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
        dividerColor: SukunColors.border,
        overlayColor: WidgetStatePropertyAll(
          SukunColors.sukunBlue.withValues(alpha: 0.06),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
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
    return SukunPaletteTheme.apply(normalTheme, accentPalette);
  }

  static ThemeData dark({
    BengaliFontChoice bengaliFont = BengaliFontChoice.liAdorNoirrit,
    double bengaliScale = 1.0,
    SukunAccentPalette accentPalette = SukunAccentPalette.sukunBlue,
  }) {
    // Dark mode follows the chosen palette: the page, cards and borders
    // are deep blue, green or plum, not a neutral grey.
    final palette = SukunColors.active;
    final background = palette.darkBackground;
    final surface = palette.darkSurface;
    final surfaceLow = palette.darkContainer;
    final outline = palette.darkOutline;
    const lightText = Color(0xFFF2F7FA);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: SukunColors.sukunBlue,
        onPrimary: Colors.black,
        primaryContainer: surfaceLow,
        onPrimaryContainer: lightText,
        secondary: palette.darkAccent,
        surface: surface,
        onSurface: lightText,
        surfaceContainerLow: surfaceLow,
        outline: outline,
      ),
      scaffoldBackgroundColor: background,
    );
    final textTheme =
        SukunTypography.withBengaliFallback(
          SukunTypography.englishTextTheme(base.textTheme),
          bengaliFont,
        ).apply(
          fontSizeFactor: AppDisplaySettings.validBengaliScale(bengaliScale),
          bodyColor: lightText,
          displayColor: lightText,
        );
    final normalTheme = base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: lightText,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: outline),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLow,
        contentTextStyle: textTheme.bodyMedium,
      ),
    );
    return SukunPaletteTheme.apply(normalTheme, accentPalette);
  }
}
