import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_palette_theme.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

double _contrast(Color a, Color b) {
  final high = a.computeLuminance() > b.computeLuminance()
      ? a.computeLuminance()
      : b.computeLuminance();
  final low = a.computeLuminance() < b.computeLuminance()
      ? a.computeLuminance()
      : b.computeLuminance();
  return (high + 0.05) / (low + 0.05);
}

void main() {
  test('the whole accent family follows the chosen palette', () {
    addTearDown(() => SukunColors.setPalette(SukunAccentPalette.sukunBlue));
    expect(SukunColors.deepTide, SukunColors.brandDeepTide);
    for (final palette in SukunAccentPalette.values) {
      SukunColors.setPalette(palette);
      expect(SukunColors.sukunBlue, palette.colors.accent);
      expect(SukunColors.deepTide, palette.colors.strong);
      expect(SukunColors.mist, palette.colors.mist);
      expect(SukunColors.canvas, palette.colors.canvas);
      expect(SukunColors.border, palette.colors.border);
    }
    // Text and status colours never change with the palette.
    expect(SukunColors.nightNavy, const Color(0xFF0D2B45));
  });

  test('all supported palette pairs meet standard text contrast', () {
    // The approved Sukun blue remains unchanged, while its button labels
    // switch from low-contrast white to accessible Night Navy.
    expect(_contrast(SukunColors.sukunBlue, Colors.white), lessThan(4.5));
    expect(
      _contrast(SukunColors.sukunBlue, SukunColors.nightNavy),
      greaterThanOrEqualTo(4.5),
    );

    for (final palette in SukunAccentPalette.values) {
      for (final brightness in Brightness.values) {
        expect(
          _contrast(
            palette.container(brightness),
            palette == SukunAccentPalette.sukunBlue
                ? (brightness == Brightness.light
                      ? SukunColors.deepTide
                      : const Color(0xFFF2F7FA))
                : palette.onContainer(brightness),
          ),
          greaterThanOrEqualTo(4.5),
          reason: '${palette.name} ${brightness.name} selected navigation',
        );
      }
      if (palette != SukunAccentPalette.sukunBlue) {
        expect(
          _contrast(palette.primary(Brightness.light), Colors.white),
          greaterThanOrEqualTo(4.5),
          reason: '${palette.name} filled button',
        );
      }
    }
  });

  testWidgets(
    'nav and resource badges remain accessible across palettes and widths',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final palette in SukunAccentPalette.values) {
        for (final brightness in Brightness.values) {
          final light = brightness == Brightness.light;
          final base = light ? ThemeData.light() : ThemeData.dark();
          // Match the approved brand container tokens without triggering
          // SukunTheme's remote Google Fonts loader in widget-test runners.
          final brandScheme = base.colorScheme.copyWith(
            primaryContainer: light
                ? SukunColors.softBlue
                : const Color(0xFF243848),
            onPrimaryContainer: light
                ? SukunColors.deepTide
                : const Color(0xFFF2F7FA),
          );
          final theme = SukunPaletteTheme.apply(
            base.copyWith(colorScheme: brandScheme),
            palette,
          );
          for (final width in <double>[360, 430, 768, 1280]) {
            await tester.binding.setSurfaceSize(Size(width, 760));
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: const Column(
                    children: [
                      SukunIconBadge(icon: Icons.auto_stories_outlined),
                      SukunStatusPill(
                        label: 'কুরআন',
                        tone: SukunStatusTone.brand,
                      ),
                    ],
                  ),
                  bottomNavigationBar: SukunBottomNavigation(
                    selectedIndex: 0,
                    destinations: const [
                      SukunNavDestination(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        label: 'হোম',
                      ),
                      SukunNavDestination(
                        icon: Icons.person_outline,
                        selectedIcon: Icons.person,
                        label: 'অ্যাকাউন্ট',
                      ),
                    ],
                    onSelected: (_) {},
                  ),
                ),
              ),
            );
            // MaterialApp animates ThemeData changes across palette/brightness.
            // Inspect the settled visual state, not the prior animation frame.
            await tester.pumpAndSettle();
            final badgeIcon = tester.widget<Icon>(
              find.descendant(
                of: find.byType(SukunIconBadge),
                matching: find.byType(Icon),
              ),
            );
            expect(badgeIcon.color, theme.colorScheme.onPrimaryContainer);
            expect(find.byType(SukunBottomNavigation), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );
}
