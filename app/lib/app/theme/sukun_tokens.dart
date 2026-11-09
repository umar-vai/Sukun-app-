import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';

/// Spacing scale for the calm Sukun layout (see docs/FINAL_UI_REFERENCE.md).
abstract final class SukunSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double page = 20;
  static const double section = 24;
  static const double sectionLarge = 28;
}

/// Corner radii shared by every surface so screens feel like one system.
abstract final class SukunRadius {
  static const double chip = 999;
  static const double control = 14;
  static const double tile = 18;
  static const double card = 22;
  static const double hero = 26;
  static const double sheet = 28;
  static const double nav = 24;
}

/// Soft elevation used instead of borders on light surfaces.
abstract final class SukunShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: SukunColors.nightNavy.withValues(alpha: 0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: SukunColors.nightNavy.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get floating => [
    BoxShadow(
      color: SukunColors.nightNavy.withValues(alpha: 0.12),
      blurRadius: 28,
      offset: const Offset(0, 8),
    ),
  ];
}
