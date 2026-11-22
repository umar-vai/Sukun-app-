import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/resource_picker_sections.dart';
import 'package:sukun_life/features/care_plans/presentation/resource_picker_sheet.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';

const _hadith = ContentResourceOption(
  id: 'hadith-1',
  title: 'Hadith resource',
  type: 'hadith',
  visibility: 'public',
  status: 'published',
);
const _dua = ContentResourceOption(
  id: 'dua-1',
  title: 'Dua resource',
  type: 'dua',
  visibility: 'public',
  status: 'published',
);
const _ruqyahAudio = ContentResourceOption(
  id: 'audio-1',
  title: 'Ruqyah audio resource',
  type: 'audio',
  visibility: 'public',
  status: 'published',
  categorySlug: 'ruqyah-audio',
);
const _surah = ContentResourceOption(
  id: 'quran:114',
  title: 'An-Nas',
  titleBn: 'আন-নাস',
  type: 'quran',
  visibility: 'public',
  status: 'published',
);
const _ruqyahAyat = ContentResourceOption(
  id: 'ayat-1',
  slug: 'srg2024-qur-001',
  title: 'Reviewed excerpt',
  type: 'article',
  visibility: 'public',
  status: 'published',
);
const _ruqyahDua = ContentResourceOption(
  id: 'dua-2',
  slug: 'srg2024-dua-001',
  title: 'Reviewed ruqyah dua',
  type: 'dua',
  visibility: 'public',
  status: 'published',
);

ContentResourceOption _libraryDua(String id, String category, String label) =>
    ContentResourceOption(
      id: id,
      title: id,
      titleBn: id,
      type: 'dua',
      visibility: 'public',
      status: 'published',
      categoryId: 'cat-$category',
      categorySlug: category,
      categoryNameBn: label,
    );

ContentResourceOption _libraryAudio(String id, String category) =>
    ContentResourceOption(
      id: id,
      title: id,
      type: 'audio',
      visibility: 'public',
      status: 'published',
      categoryId: 'cat-$category',
      categorySlug: category,
      categoryNameBn: category,
    );

void main() {
  test('Admin main sections use the public Resources taxonomy', () {
    expect(resourceSections.length, 10);
    final hadith = resourceSectionBySlug('hadith')!;
    final dua = resourceSectionBySlug('dua-azkar')!;
    final ruqyah = resourceSectionBySlug('ruqyah')!;
    final audio = resourceSectionBySlug('audio')!;

    expect(resourceMatchesPickerSection(_hadith, hadith), isTrue);
    expect(resourceMatchesPickerSection(_hadith, dua), isFalse);
    expect(resourceMatchesPickerSection(_dua, dua), isTrue);
    expect(resourceMatchesPickerSection(_ruqyahAudio, ruqyah), isTrue);
    expect(resourceMatchesPickerSection(_ruqyahAudio, audio), isTrue);
    expect(_surah.canonicalSurahNumber, 114);
    expect(_surah.isLinkable, isTrue);
    expect(
      resourceMatchesPickerSection(_surah, resourceSectionBySlug('quran')!),
      isTrue,
    );
    expect(
      resourceMatchesPickerSection(
        _ruqyahAyat,
        resourceSectionBySlug('quran')!,
      ),
      isTrue,
    );
    expect(resourceMatchesPickerSection(_ruqyahAyat, ruqyah), isTrue);
    expect(_ruqyahDua.categoryLabel, 'রুকইয়াহ দোয়া');
    expect(resourceMatchesPickerSection(_ruqyahDua, ruqyah), isTrue);
  });

  testWidgets('sections open as a grid and items show inside', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showResourcePickerSheet(
                context: context,
                resources: const [_hadith, _dua, _ruqyahAudio],
                selectedId: '',
              ),
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    // The first view is the library-style section grid.
    expect(find.byKey(const Key('resource-section-hadith')), findsOneWidget);
    expect(find.text('Hadith resource'), findsNothing);

    await tester.tap(find.byKey(const Key('resource-section-hadith')));
    await tester.pumpAndSettle();
    expect(find.text('Hadith resource'), findsOneWidget);
    expect(find.text('Dua resource'), findsNothing);

    await tester.tap(find.byKey(const Key('resource-section-back')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('resource-picker-search')),
      'dua',
    );
    await tester.pumpAndSettle();
    // Live suggestions appear under the field while typing, and the
    // matching item is also in the results grid.
    expect(find.byKey(const Key('live-search-suggestions')), findsOneWidget);
    expect(find.byKey(const Key('resource-item-dua-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('resource-item-dua-1')));
    await tester.pumpAndSettle();
    expect(result, 'dua-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('multi picker ticks several items and returns them in order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showResourceMultiPickerSheet(
                    context: context,
                    resources: const [_hadith, _dua, _ruqyahAudio],
                    alreadyLinked: const {'hadith-1'},
                  ),
              child: const Text('Open multi'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open multi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resource-section-all')));
    await tester.pumpAndSettle();

    // Already linked items cannot be ticked again.
    await tester.tap(find.byKey(const Key('resource-item-hadith-1')));
    await tester.tap(find.byKey(const Key('resource-item-audio-1')));
    await tester.tap(find.byKey(const Key('resource-item-dua-1')));
    await tester.pump();
    expect(find.text('২টি যোগ করুন'), findsOneWidget);
    await tester.tap(find.byKey(const Key('resource-picker-add')));
    await tester.pumpAndSettle();
    expect(result, ['audio-1', 'dua-1']);
    expect(tester.takeException(), isNull);
  });

  for (final wholeSurah in [false, true]) {
    testWidgets(
      'routine resource picker returns a canonical ${wholeSurah ? 'surah' : 'ayah'} reference',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? result;
        bool? requestedWholeSurah;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showResourcePickerSheet(
                      context: context,
                      resources: const [_dua],
                      selectedId: '',
                      onPickCanonicalQuran: (context, full) async {
                        requestedWholeSurah = full;
                        return full ? 'quran:114' : 'quran:2:255';
                      },
                    );
                  },
                  child: const Text('Open routine picker'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open routine picker'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('routine-quran-ayah-entry')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('routine-quran-surah-entry')),
          findsOneWidget,
        );
        final key = wholeSurah
            ? const Key('routine-quran-surah-entry')
            : const Key('routine-quran-ayah-entry');
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(requestedWholeSurah, wholeSurah);
        expect(result, wholeSurah ? 'quran:114' : 'quran:2:255');
        expect(find.text('Open routine picker'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('fixed light resource picker stays readable in dark theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const draftResource = ContentResourceOption(
      id: 'draft-qa',
      title: 'Unpublished test item',
      type: 'dua',
      visibility: 'public',
      status: 'draft',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showResourcePickerSheet(
                context: context,
                resources: const [_hadith, draftResource],
                selectedId: '',
              ),
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resource-section-all')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text('কোনো উপকরণ নয়')).style?.color,
      SukunColors.nightNavy,
    );
    expect(
      tester.widget<Text>(find.text('Hadith resource')).style?.color,
      SukunColors.nightNavy,
    );
    expect(
      tester.widget<Text>(find.text('Unpublished test item')).style?.color,
      SukunColors.nightNavy,
    );
    // Unpublished records remain unavailable rather than becoming selectable.
    expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin library mirrors the Resources tab group navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final resources = [
      _libraryDua('sleep-basic', 'dua-azkar-ma-07', 'ঘুমের আগে প্রাথমিক'),
      _libraryDua('sleep-tasbih', 'dua-azkar-ma-09', 'ঘুমের আগে ফজিলত'),
      _libraryDua('enemy', 'dua-azkar-ma-14', 'শত্রুর ক্ষতির আশংকা করলে'),
      _libraryAudio('eye-audio', 'ruqyah-lib-topic'),
      _libraryAudio('hibshi-audio', 'ruqyah-lib-hibshi'),
    ];
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showResourcePickerSheet(
                context: context,
                resources: resources,
                selectedId: '',
              ),
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    // দোয়া ও যিকর → groups (only those with items) → categories → items.
    await tester.tap(find.byKey(const Key('resource-section-dua-azkar')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('resource-group-masnun-sleep')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-group-masnun-daily')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-group-masnun-morning-evening')),
      findsNothing,
    );
    expect(find.byKey(const Key('resource-group-time-based')), findsNothing);
    expect(find.byKey(const Key('resource-item-sleep-basic')), findsNothing);

    await tester.tap(find.byKey(const Key('resource-group-masnun-sleep')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('resource-nav-category-dua-azkar-ma-07')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('resource-nav-category-dua-azkar-ma-09')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('resource-item-sleep-tasbih')), findsOneWidget);
    expect(find.byKey(const Key('resource-item-sleep-basic')), findsNothing);

    // Back walks up one level at a time: category → group → section.
    await tester.tap(find.byKey(const Key('resource-section-back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('resource-nav-category-dua-azkar-ma-07')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('resource-section-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resource-section-back')));
    await tester.pumpAndSettle();

    // রুকইয়াহ → রুকইয়াহ অডিও → the RuqyahBD audio groups.
    await tester.tap(find.byKey(const Key('resource-section-ruqyah')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resource-group-ruqyah-audio')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('resource-nav-category-ruqyah-lib-topic')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-nav-category-ruqyah-lib-hibshi')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('resource-nav-category-ruqyah-lib-hibshi')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('resource-item-hibshi-audio')));
    await tester.pumpAndSettle();
    expect(result, 'hibshi-audio');
    expect(tester.takeException(), isNull);
  });
}
