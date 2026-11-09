import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/features/resources/data/quran_last_read_store.dart';
import 'package:sukun_life/features/resources/presentation/quran_continue_card.dart';
import 'package:sukun_life/features/resources/presentation/quran_tabbed_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    QuranLastReadStore.resetForTest();
  });

  test('only valid surah and ayah positions are restored', () {
    expect(
      QuranLastRead.fromJson({'surah': 2, 'ayah': 255, 'title': 'আল-বাকারা'}),
      const QuranLastRead(surah: 2, ayah: 255, title: 'আল-বাকারা'),
    );
    expect(QuranLastRead.fromJson({'surah': 115, 'ayah': 1}), isNull);
    expect(QuranLastRead.fromJson({'surah': 2, 'ayah': 0}), isNull);
    expect(QuranLastRead.fromJson('broken'), isNull);
    expect(QuranLastRead.fromJson({'surah': 1, 'ayah': 3})!.title, 'সূরা 1');
  });

  test(
    'the place survives a restart and is cleared on account change',
    () async {
      await QuranLastReadStore.save(
        const QuranLastRead(surah: 18, ayah: 10, title: 'আল-কাহফ'),
      );
      QuranLastReadStore.resetForTest();
      await QuranLastReadStore.load();
      expect(QuranLastReadStore.current.value?.surah, 18);
      expect(
        QuranLastReadStore.current.value?.route,
        '/resources/quran/18?ayah=10',
      );

      await QuranLastReadStore.clear();
      QuranLastReadStore.resetForTest();
      await QuranLastReadStore.load();
      expect(QuranLastReadStore.current.value, isNull);
    },
  );

  testWidgets('continue card is hidden until a place is saved', (tester) async {
    QuranLastRead? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: QuranContinueCard(onOpen: (p) => opened = p)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quran-continue-reading')), findsNothing);

    await QuranLastReadStore.save(
      const QuranLastRead(surah: 36, ayah: 12, title: 'ইয়াসিন'),
    );
    await tester.pump();
    expect(find.text('চালিয়ে পড়ুন'), findsOneWidget);
    expect(find.text('ইয়াসিন'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quran-continue-reading')));
    expect(opened?.ayah, 12);
  });

  testWidgets('surah list shows the continue card above the surahs', (
    tester,
  ) async {
    await QuranLastReadStore.save(
      const QuranLastRead(surah: 1, ayah: 4, title: 'আল-ফাতিহা'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuranSurahList(
            chapters: const [
              {'id': 1, 'name_simple': 'Al-Faatihah', 'verses_count': 7},
            ],
            chapterTitle: (c) => c['name_simple'] as String,
            onOpenSurah: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quran-continue-reading')), findsOneWidget);
    expect(find.text('Al-Faatihah'), findsOneWidget);
    expect(find.text('7 আয়াত'), findsOneWidget);
  });
}
