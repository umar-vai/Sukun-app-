import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/presentation/ruqyah_ayat_collection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('authorized snapshot contains all eight source groups and 105 entries',
      () async {
    final catalog = await RuqyahCollection.load();
    expect(catalog.groups.length, 8);
    expect(catalog.entries.length, 105);
    expect(catalog.groups.first.title, 'বেসিক রুকইয়াহ');
    expect(catalog.groups.last.title, 'আয়াাতুস সাকিনাহ');
    final expectedCounts = <int, int>{
      1: 8, 2: 20, 3: 32, 4: 5, 5: 3, 6: 6, 7: 25, 8: 6,
    };
    for (final group in catalog.groups) {
      expect(
        catalog.entries.where((e) => e.groupId == group.id).length,
        expectedCounts[group.id],
      );
    }
    expect(
      catalog.entries.first.arabic,
      contains('أَعُوْذُ بِكَلِمَاتِ'),
    );
    expect(
      catalog.entries.first.bangla,
      contains('আল্লাহর পরিপূর্ণ'),
    );
    expect(
      catalog.entries.where((e) => e.audioUrl != null).length,
      103,
    );
    expect(
      catalog.entries.first.audioUrl,
      'https://files.ruqyahbd.org/appfiles/ruqyah-ayat/3_2.mp3',
    );
  });

  test('audio URL validation rejects missing and arbitrary paths', () {
    const empty = RuqyahEntry(1, 1, 1, 'sample', 'arabic', 'bangla', null, '0');
    const unsafe = RuqyahEntry(
      2, 1, 2, 'sample', 'arabic', 'bangla', null,
      'https://example.com/private',
    );
    expect(empty.audioUrl, isNull);
    expect(unsafe.audioUrl, isNull);
  });

  testWidgets('eight-card index is rendered in the actual Flutter resources UI',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RuqyahAyatCollectionScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('রুকইয়াহ আয়াত'), findsOneWidget);
    expect(find.text('বেসিক রুকইয়াহ'), findsOneWidget);
    expect(find.text('৮টি আয়াত ও দোয়া'), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
