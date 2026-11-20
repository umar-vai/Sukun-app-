import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';

/// Where a glass panel sits, which decides how its frosted tint is mixed.
enum SukunGlassTone {
  /// On the normal page background (cards, panels, navigation).
  surface,

  /// On a coloured hero or app bar (white frost over the accent colour).
  onColor,

  /// A selected or highlighted panel, tinted with the palette container.
  accent,
}

/// iOS style frosted glass: the content behind the panel is blurred and its
/// colours are slightly boosted, then a translucent tint, a light top sheen
/// and a fine bright edge are laid over it.
///
/// Every panel shares the nearest [BackdropGroup] so long lists of glass
/// cards are blurred in one pass instead of one pass per card.
class SukunGlass extends StatelessWidget {
  const SukunGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.tone = SukunGlassTone.surface,
    this.blur = 22,
    this.padding,
    this.tint,
    this.showBorder = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final SukunGlassTone tone;
  final double blur;
  final EdgeInsetsGeometry? padding;

  /// Optional colour mixed into the frost instead of the tone default.
  final Color? tint;
  final bool showBorder;

  /// Slight saturation boost (iOS "vibrancy") applied before the blur.
  static const List<double> _saturate = <double>[
    1.18, -0.15, -0.03, 0, 0, //
    -0.05, 1.08, -0.03, 0, 0, //
    -0.05, -0.15, 1.20, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// The frost colours for [tone] in the current brightness.
  static (Color top, Color bottom, Color edge) colorsFor(
    BuildContext context,
    SukunGlassTone tone, {
    Color? tint,
  }) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final palette = SukunColors.active;
    switch (tone) {
      case SukunGlassTone.onColor:
        return (
          Colors.white.withValues(alpha: 0.24),
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.34),
        );
      case SukunGlassTone.accent:
        final base = tint ?? (night ? palette.darkContainer : palette.soft);
        return (
          base.withValues(alpha: night ? 0.72 : 0.78),
          base.withValues(alpha: night ? 0.52 : 0.58),
          Colors.white.withValues(alpha: night ? 0.10 : 0.70),
        );
      case SukunGlassTone.surface:
        final base = tint ?? (night ? palette.darkSurface : Colors.white);
        return (
          base.withValues(alpha: night ? 0.70 : 0.80),
          base.withValues(alpha: night ? 0.50 : 0.58),
          Colors.white.withValues(alpha: night ? 0.10 : 0.78),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (top, bottom, edge) = colorsFor(context, tone, tint: tint);
    final filter = ui.ImageFilter.compose(
      outer: ui.ImageFilter.blur(
        sigmaX: blur,
        sigmaY: blur,
        tileMode: TileMode.mirror,
      ),
      inner: const ColorFilter.matrix(_saturate),
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: filter,
        backdropGroupKey: BackdropGroup.of(context)?.backdropKey,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [top, bottom],
            ),
            border: showBorder ? Border.all(color: edge, width: 1) : null,
          ),
          child: DecoratedBox(
            // A soft specular sheen across the upper edge, like iOS glass.
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.white.withValues(
                    alpha: tone == SukunGlassTone.onColor ? 0.10 : 0.06,
                  ),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
            child: padding == null
                ? child
                : Padding(padding: padding!, child: child),
          ),
        ),
      ),
    );
  }
}

/// The calm, palette-tinted page background that glass panels float on.
/// Soft colour fields (no images, no blur cost) give the frost something
/// to pick up, in both Light and Dark mode.
class SukunAmbientBackground extends StatelessWidget {
  const SukunAmbientBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    final palette = SukunColors.active;
    final base = night ? palette.darkBackground : palette.canvas;
    final glowA = palette.accent.withValues(alpha: night ? 0.26 : 0.20);
    final glowB = (night ? palette.darkAccent : palette.strong).withValues(
      alpha: night ? 0.14 : 0.10,
    );
    final glowC = SukunColors.saffron.withValues(alpha: night ? 0.05 : 0.08);
    final background = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: base,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                palette.accent.withValues(alpha: night ? 0.10 : 0.06),
                base,
              ),
              base,
              Color.alphaBlend(
                palette.strong.withValues(alpha: night ? 0.10 : 0.05),
                base,
              ),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Glow(alignment: const Alignment(1.1, -0.85), color: glowA),
            _Glow(alignment: const Alignment(-1.2, 0.15), color: glowB),
            _Glow(alignment: const Alignment(0.9, 1.05), color: glowC),
          ],
        ),
      ),
    );
    if (child == null) return background;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: background),
        child!,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.alignment, required this.color});

  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: alignment,
        radius: 0.95,
        colors: [color, color.withValues(alpha: 0)],
      ),
    ),
  );
}

/// Gives every page route the ambient background, so scaffolds can stay
/// transparent and their glass panels have colour behind them, while page
/// transitions still cover the previous screen completely.
class SukunAmbientPageTransitionsBuilder extends PageTransitionsBuilder {
  const SukunAmbientPageTransitionsBuilder();

  static const PageTransitionsTheme _platformDefaults = PageTransitionsTheme();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _platformDefaults.buildTransitions<T>(
    route,
    context,
    animation,
    secondaryAnimation,
    SukunAmbientBackground(child: child),
  );
}

/// Page transitions for every platform with the ambient background.
const sukunAmbientPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: SukunAmbientPageTransitionsBuilder(),
    TargetPlatform.iOS: SukunAmbientPageTransitionsBuilder(),
    TargetPlatform.macOS: SukunAmbientPageTransitionsBuilder(),
    TargetPlatform.windows: SukunAmbientPageTransitionsBuilder(),
    TargetPlatform.linux: SukunAmbientPageTransitionsBuilder(),
    TargetPlatform.fuchsia: SukunAmbientPageTransitionsBuilder(),
  },
);

/// Drop-in frosted replacement for [Card]: the same margin, shape, clipping
/// and ink behaviour, drawn as glass. An explicit [color] tints the frost.
class SukunGlassCard extends StatelessWidget {
  const SukunGlassCard({
    super.key,
    this.child,
    this.color,
    this.margin,
    this.shape,
    this.clipBehavior,
    this.elevation,
    this.semanticContainer = true,
  });

  final Widget? child;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final ShapeBorder? shape;
  final Clip? clipBehavior;

  /// Accepted for [Card] compatibility; glass cards stay flat.
  final double? elevation;
  final bool semanticContainer;

  @override
  Widget build(BuildContext context) {
    final cardTheme = CardTheme.of(context);
    final resolvedShape =
        shape ??
        cardTheme.shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        );
    final radius = resolvedShape is RoundedRectangleBorder
        ? resolvedShape.borderRadius.resolve(Directionality.of(context))
        : BorderRadius.circular(12);
    return Padding(
      padding: margin ?? cardTheme.margin ?? const EdgeInsets.all(4),
      child: SukunGlass(
        borderRadius: radius,
        tint: color,
        tone: color == null ? SukunGlassTone.surface : SukunGlassTone.accent,
        child: Card(
          margin: EdgeInsets.zero,
          color: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: resolvedShape is RoundedRectangleBorder
              ? RoundedRectangleBorder(borderRadius: radius)
              : resolvedShape,
          clipBehavior: clipBehavior,
          semanticContainer: semanticContainer,
          child: child,
        ),
      ),
    );
  }
}
