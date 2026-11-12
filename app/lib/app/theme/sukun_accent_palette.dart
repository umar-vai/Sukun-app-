import 'package:flutter/material.dart';

/// Optional interface accents. Blue stays the approved Sukun brand default;
/// never recolor the official logo or canonical Qur'an content.
///
/// Each palette carries the full accent family (not only the button colour),
/// so a palette change recolours headers, chips, tiles, icons, page tints and
/// borders across the whole app. `SukunColors` reads the active set.
enum SukunAccentPalette {
  sukunBlue,
  calmTeal,
  twilightPlum;

  String get label => switch (this) {
    SukunAccentPalette.sukunBlue => 'সুকুন ব্লু',
    SukunAccentPalette.calmTeal => 'শান্ত সবুজ',
    SukunAccentPalette.twilightPlum => 'সন্ধ্যার বেগুনি',
  };

  SukunAccentSet get colors => switch (this) {
    SukunAccentPalette.sukunBlue => SukunAccentSet.sukunBlue,
    SukunAccentPalette.calmTeal => SukunAccentSet.calmTeal,
    SukunAccentPalette.twilightPlum => SukunAccentSet.twilightPlum,
  };

  Color get previewColor => colors.accent;

  /// Filled-button colour. Brand blue keeps its approved value; the other
  /// palettes use their strong tone so white labels stay readable (WCAG AA).
  Color primary(Brightness brightness) =>
      this == SukunAccentPalette.sukunBlue ? colors.accent : colors.strong;

  Color container(Brightness brightness) => switch (brightness) {
    Brightness.light => colors.soft,
    Brightness.dark => colors.darkContainer,
  };

  Color onContainer(Brightness brightness) =>
      brightness == Brightness.light ? colors.strong : const Color(0xFFF2F7FA);
}

/// One palette's full family of accent colours.
@immutable
class SukunAccentSet {
  const SukunAccentSet({
    required this.accent,
    required this.strong,
    required this.mist,
    required this.soft,
    required this.pale,
    required this.canvas,
    required this.border,
    required this.darkContainer,
  });

  /// Main accent (Sukun Blue in the brand palette).
  final Color accent;

  /// Strong accent with white-text contrast (Deep Tide in the brand palette).
  final Color strong;

  /// Light accent surface (Mist).
  final Color mist;

  /// Selected / container tint.
  final Color soft;

  /// Very light row tint.
  final Color pale;

  /// Page background.
  final Color canvas;

  /// Card and input border.
  final Color border;

  /// Dark mode selected container.
  final Color darkContainer;

  static const sukunBlue = SukunAccentSet(
    accent: Color(0xFF0F9BD7),
    strong: Color(0xFF0A70A8),
    mist: Color(0xFFE8F5FC),
    soft: Color(0xFFDDF2FB),
    pale: Color(0xFFF1F9FD),
    canvas: Color(0xFFF7FBFD),
    border: Color(0xFFD9E8EF),
    darkContainer: Color(0xFF243848),
  );

  static const calmTeal = SukunAccentSet(
    accent: Color(0xFF1E9C88),
    strong: Color(0xFF146F63),
    mist: Color(0xFFE6F5F1),
    soft: Color(0xFFD5EFE8),
    pale: Color(0xFFF0FAF7),
    canvas: Color(0xFFF6FBF9),
    border: Color(0xFFD3E7E1),
    darkContainer: Color(0xFF253D39),
  );

  static const twilightPlum = SukunAccentSet(
    accent: Color(0xFF8A5DBE),
    strong: Color(0xFF67418F),
    mist: Color(0xFFF2ECF9),
    soft: Color(0xFFE7DCF4),
    pale: Color(0xFFF8F4FC),
    canvas: Color(0xFFFAF7FD),
    border: Color(0xFFE4DAEF),
    darkContainer: Color(0xFF352C42),
  );
}
