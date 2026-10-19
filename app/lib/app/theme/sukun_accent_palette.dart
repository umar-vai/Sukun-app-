import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';

/// Optional interface accents. Blue stays the approved Sukun brand default;
/// never recolor the official logo or canonical Qur'an content.
enum SukunAccentPalette {
  sukunBlue,
  calmTeal,
  twilightPlum;

  String get label => switch (this) {
    sukunBlue => 'সুকুন ব্লু',
    calmTeal => 'শান্ত সবুজ',
    twilightPlum => 'সন্ধ্যার বেগুনি',
  };

  Color get previewColor => primary(Brightness.light);

  Color primary(Brightness brightness) => switch (this) {
    sukunBlue => SukunColors.sukunBlue,
    calmTeal => const Color(0xFF146F63),
    twilightPlum => const Color(0xFF67418F),
  };

  Color container(Brightness brightness) => switch ((this, brightness)) {
    (SukunAccentPalette.sukunBlue, Brightness.light) => SukunColors.softBlue,
    (SukunAccentPalette.sukunBlue, Brightness.dark) => const Color(0xFF243848),
    (SukunAccentPalette.calmTeal, Brightness.light) => const Color(0xFFE4F4EF),
    (SukunAccentPalette.calmTeal, Brightness.dark) => const Color(0xFF253D39),
    (SukunAccentPalette.twilightPlum, Brightness.light) => const Color(0xFFF0EAF8),
    (SukunAccentPalette.twilightPlum, Brightness.dark) => const Color(0xFF352C42),
  };

  Color onContainer(Brightness brightness) =>
      brightness == Brightness.light
      ? const Color(0xFF142C34)
      : const Color(0xFFF2F7FA);
}
