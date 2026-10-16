import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/presentation/quran_tabbed_screen.dart';

void main() {
  testWidgets('Quran opens first with a separate Ruqyah Ayat tab', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: QuranTabbedScreen()));

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.tabs, hasLength(2));
    expect(find.text('কুরআন'), findsWidgets);
    expect(find.text('রুকইয়াহ আয়াত'), findsOneWidget);

    await tester.tap(find.text('রুকইয়াহ আয়াত'));
    await tester.pumpAndSettle();
    expect(
      DefaultTabController.of(tester.element(find.byType(TabBar))).index,
      1,
    );
  });
  testWidgets('surah catalog opens directly on the chapters', (tester) async {
    final opened = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuranSurahList(
            chapters: const [
              {'id': 1, 'name_simple': 'Al-Faatihah', 'verses_count': 7},
              {'id': 2, 'name_simple': 'Al-Baqarah', 'verses_count': 286},
            ],
            chapterTitle: (chapter) => chapter['name_simple'] as String,
            onOpenSurah: opened.add,
          ),
        ),
      ),
    );
    expect(find.text('Al-Faatihah'), findsOneWidget);
    expect(find.text('Al-Baqarah'), findsOneWidget);
    expect(find.text('কুরআনের সূরাসমূহ'), findsNothing);
    expect(find.textContaining('API থেকে আনা হয়'), findsNothing);
    expect(find.textContaining('Al Quran Cloud API থেকে'), findsNothing);
    await tester.tap(find.text('Al-Faatihah'));
    expect(opened, [1]);
  });
}
