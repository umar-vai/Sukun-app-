import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_palette_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('approved blue leaves the original theme untouched', () {
    final light = ThemeData.light();
    final dark = ThemeData.dark();
    expect(
      SukunPaletteTheme.apply(light, SukunAccentPalette.sukunBlue),
      same(light),
    );
    expect(
      SukunPaletteTheme.apply(dark, SukunAccentPalette.sukunBlue),
      same(dark),
    );
    expect(SukunAccentPalette.sukunBlue.previewColor, SukunColors.sukunBlue);
  });

  test('optional palettes update semantic controls in both modes', () {
    for (final palette in [
      SukunAccentPalette.calmTeal,
      SukunAccentPalette.twilightPlum,
    ]) {
      for (final brightness in Brightness.values) {
        final base = brightness == Brightness.light
            ? ThemeData.light()
            : ThemeData.dark();
        final theme = SukunPaletteTheme.apply(base, palette);
        expect(theme.colorScheme.primary, palette.primary(brightness));
        expect(
          theme.colorScheme.primaryContainer,
          palette.container(brightness),
        );
        expect(theme.colorScheme.onPrimary, Colors.white);
        expect(
          theme.floatingActionButtonTheme.backgroundColor,
          palette.primary(brightness),
        );
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
