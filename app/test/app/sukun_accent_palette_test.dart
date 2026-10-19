import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_theme.dart';

void main() {
  test('approved Sukun blue remains the default light and dark accent', () {
    expect(SukunTheme.light().colorScheme.primary, SukunColors.sukunBlue);
    expect(SukunTheme.dark().colorScheme.primary, SukunColors.sukunBlue);
  });

  test('optional palettes update semantic controls in both modes', () {
    for (final palette in [
      SukunAccentPalette.calmTeal,
      SukunAccentPalette.twilightPlum,
    ]) {
      for (final brightness in Brightness.values) {
        final theme = brightness == Brightness.light
            ? SukunTheme.light(accentPalette: palette)
            : SukunTheme.dark(accentPalette: palette);
        expect(theme.colorScheme.primary, palette.primary(brightness));
        expect(
          theme.colorScheme.primaryContainer,
          palette.container(brightness),
        );
        expect(theme.colorScheme.onPrimary, Colors.white);
        expect(theme.floatingActionButtonTheme.backgroundColor, palette.primary(brightness));
      }
    }
  });

  test('all palettes have readable light and dark semantic container text', () {
    for (final palette in SukunAccentPalette.values) {
      expect(palette.label.isNotEmpty, isTrue);
      for (final brightness in Brightness.values) {
        expect(
          palette.container(brightness),
          isNot(palette.onContainer(brightness)),
        );
      }
    }
  });
}
