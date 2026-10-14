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
    expect(find.text('রুকইয়াহ আয়াত ও অংশ'), findsOneWidget);
  });
}
