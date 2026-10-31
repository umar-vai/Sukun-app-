import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/features/home/presentation/unified_home_screen.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_schedule.dart';

void main() {
  for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
    testWidgets('selected prayer is readable in ${brightness.name} mode', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final entry = PrayerTimeEntry(
        id: 'fajr',
        label: 'Fajr',
        time: DateTime(2026, 11, 1, 5, 10),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: Column(
              children: [
                HomePrayerTimeChip(entry: entry, highlighted: true),
                HomePrayerTimeChip(
                  entry: PrayerTimeEntry(
                    id: 'dhuhr',
                    label: 'Dhuhr',
                    time: DateTime(2026, 11, 1, 12, 15),
                  ),
                  highlighted: false,
                ),
              ],
            ),
          ),
        ),
      );

      final active = tester.widget<Container>(
        find.byKey(const Key('home-prayer-chip-fajr')),
      );
      final decoration = active.decoration! as BoxDecoration;
      expect(decoration.color, SukunColors.deepTide);
      expect(decoration.color, isNot(Colors.white));

      final label = tester.widget<Text>(
        find.byKey(const Key('home-prayer-label-fajr')),
      );
      final time = tester.widget<Text>(
        find.byKey(const Key('home-prayer-time-fajr')),
      );
      expect(label.data, 'ফজর');
      expect(label.style?.color, Colors.white);
      expect(time.data, isNotEmpty);
      expect(time.style?.color, Colors.white);

      final ordinary = tester.widget<Container>(
        find.byKey(const Key('home-prayer-chip-dhuhr')),
      );
      expect((ordinary.decoration! as BoxDecoration).color, Colors.transparent);
      expect(tester.takeException(), isNull);
    });
  }
}
