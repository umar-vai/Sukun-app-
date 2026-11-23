import 'package:flutter/material.dart';

/// Two open hands raised in dua: the owner-supplied artwork (2026-11-23),
/// cropped to `assets/icons/dua_hands.png` with a transparent background.
/// The artwork is a single-colour line drawing, so it is tinted with the
/// surrounding icon colour and follows light and dark themes.
class DuaHandsIcon extends StatelessWidget {
  const DuaHandsIcon({super.key, this.size = 24, this.color});

  static const asset = 'assets/icons/dua_hands.png';

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    color: color ?? IconTheme.of(context).color,
    colorBlendMode: BlendMode.srcIn,
    filterQuality: FilterQuality.medium,
    semanticLabel: 'দোয়ার হাত',
  );
}
