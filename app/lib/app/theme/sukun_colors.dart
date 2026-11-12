import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';

/// Sukun design colours.
///
/// The accent family (`sukunBlue`, `deepTide`, `mist`, `softBlue`,
/// `paleBlue`, `canvas`, `border`) follows the palette chosen in Settings, so
/// the whole interface changes colour, not only the buttons. With the default
/// Sukun Blue palette they are exactly the official brand tokens. The names
/// are kept so existing screens follow the palette without edits.
abstract final class SukunColors {
  static SukunAccentSet _active = SukunAccentSet.sukunBlue;

  /// The active accent family. Set by the app root before building themes.
  static SukunAccentSet get active => _active;

  /// Returns true when the palette changed.
  static bool setPalette(SukunAccentPalette palette) {
    final next = palette.colors;
    if (identical(next, _active)) return false;
    _active = next;
    return true;
  }

  /// Official brand tokens, never affected by the palette (logo, docs).
  static const brandBlue = Color(0xFF0F9BD7);
  static const brandDeepTide = Color(0xFF0A70A8);
  static const brandMist = Color(0xFFE8F5FC);

  static Color get sukunBlue => _active.accent;
  static Color get deepTide => _active.strong;
  static const nightNavy = Color(0xFF0D2B45);
  static Color get mist => _active.mist;
  static const saffron = Color(0xFFF2C45A);

  static Color get canvas => _active.canvas;
  static Color get paleBlue => _active.pale;
  static Color get softBlue => _active.soft;
  static Color get border => _active.border;
  static const muted = Color(0xFF607889);
  static const navySoft = Color(0xFF183F5B);

  static const success = Color(0xFF247A5A);
  static const successSoft = Color(0xFFE5F5EE);
  static const warningSoft = Color(0xFFFFF6DD);
  static const error = Color(0xFFB42318);
  static const errorSoft = Color(0xFFFDECEA);
  static const surface = Colors.white;
}
