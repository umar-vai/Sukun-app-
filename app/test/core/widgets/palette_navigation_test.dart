import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';
import 'package:sukun_life/app/theme/sukun_palette_theme.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

void main() {
  testWidgets(
    'branded navigation and resource badges follow theme on phones and desktop',
    (tester) async {
      final palette = SukunAccentPalette.calmTeal;
      final theme = SukunPaletteTheme.apply(ThemeData.light(), palette);
      for (final width in <double>[360, 430, 1280]) {
        await tester.binding.setSurfaceSize(Size(width, 760));
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: const Column(
                children: [
                  SukunIconBadge(icon: Icons.auto_stories_outlined),
                  SukunStatusPill(label: 'কুরআন', tone: SukunStatusTone.brand),
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
        await tester.pump();
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
      await tester.binding.setSurfaceSize(null);
    },
  );
}
