import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  test('Admin main sections use the public Resources taxonomy', () {
    expect(resourceSections.length, 8);
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
  });

  testWidgets('wheel and arrow change the visible resource section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showResourcePickerSheet(
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
    expect(find.text('Hadith resource'), findsOneWidget);

    final carousel = find.byKey(const Key('resource-section-carousel'));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(carousel),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hadith resource'), findsNothing);

    await tester.tap(find.byKey(const Key('resource-section-next')));
    await tester.pumpAndSettle();
    expect(find.text('Hadith resource'), findsOneWidget);
    expect(find.text('Dua resource'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
