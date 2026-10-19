import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';

/// Applies a selected interface palette to semantic Material components.
/// The approved Sukun Blue theme is returned unchanged; official brand
/// assets and Qur'an content are never recolored.
abstract final class SukunPaletteTheme {
  static ThemeData apply(ThemeData theme, SukunAccentPalette palette) {
    if (palette == SukunAccentPalette.sukunBlue) return theme;

    final brightness = theme.brightness;
    final accent = palette.primary(brightness);
    final container = palette.container(brightness);
    final onContainer = palette.onContainer(brightness);
    final scheme = theme.colorScheme.copyWith(
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: container,
      onPrimaryContainer: onContainer,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: container,
      onSecondaryContainer: onContainer,
      surfaceTint: accent,
    );
    final enabledAccent = WidgetStateProperty.resolveWith<Color?>(
      (states) => states.contains(WidgetState.disabled) ? null : accent,
    );
    final enabledWhite = WidgetStateProperty.resolveWith<Color?>(
      (states) => states.contains(WidgetState.disabled) ? null : Colors.white,
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accent, width: 2),
    );

    return theme.copyWith(
      colorScheme: scheme,
      filledButtonTheme: FilledButtonThemeData(
        style: (theme.filledButtonTheme.style ?? FilledButton.styleFrom())
            .copyWith(backgroundColor: enabledAccent, foregroundColor: enabledWhite),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (theme.outlinedButtonTheme.style ?? OutlinedButton.styleFrom())
            .copyWith(foregroundColor: enabledAccent),
      ),
      textButtonTheme: TextButtonThemeData(
        style: (theme.textButtonTheme.style ?? TextButton.styleFrom())
            .copyWith(foregroundColor: enabledAccent),
      ),
      floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        focusedBorder: focusedBorder,
      ),
      progressIndicatorTheme: theme.progressIndicatorTheme.copyWith(
        color: accent,
        linearTrackColor: container,
      ),
      chipTheme: theme.chipTheme.copyWith(
        selectedColor: container,
        checkmarkColor: accent,
      ),
    );
  }
}
