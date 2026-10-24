import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/ruqyah_topic_browser.dart';

void main() {
  ContentResource audio(String id, String title) => ContentResource(
    id: id,
    type: 'audio',
    title: title,
    categorySlug: 'ruqyah-audio',
    mediaSourceType: 'direct_audio_url',
    mediaUrl: 'https://example.org/audio.mp3',
    visibility: 'public',
    status: 'published',
  );

  testWidgets(
    'Ruqyah displays grouped audio without repeating a default card',
    (tester) async {
      tester.view.physicalSize = const Size(390, 880);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = [
        audio('kursi', 'আয়াতুল কুরসির রুকইয়াহ'),
        audio('bakara', 'সুরা বাকারা — শায়খ সুদাইস'),
        audio('qul', 'তিনকুলের রুকইয়াহ'),
        audio('eye', 'বদনজরের রুকইয়াহ'),
        audio('jinn', 'জিনের আছরের রুকইয়াহ'),
      ];
      String? opened;
      var openAyat = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: RuqyahTopicBrowser(
                  resources: items,
                  onOpenResource: (item) => opened = item.id,
                  onOpenAyat: () => openAyat++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ruqyah-filter-all')), findsOneWidget);
      expect(
        find.byKey(const Key('ruqyah-group-ruqyah-recitation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ruqyah-group-ruqyah-evil-eye')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ruqyah-item-kursi')), findsOneWidget);
      expect(find.byKey(const Key('ruqyah-item-qul')), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        find.byKey(const Key('ruqyah-show-ruqyah-recitation')),
      );
      await tester.tap(find.byKey(const Key('ruqyah-show-ruqyah-recitation')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ruqyah-item-qul')), findsOneWidget);
      await tester.ensureVisible(find.text('তিনকুলের রুকইয়াহ'));
      await tester.tap(find.text('তিনকুলের রুকইয়াহ'));
      expect(opened, 'qul');

      // Ayat shortcut belongs to All/Ayat views, not the audio topic.
      expect(find.byKey(const Key('ruqyah-open-ayat')), findsNothing);
      expect(openAyat, 0);
    },
  );

  testWidgets(
    'Ruqyah ayat and main types remain accessible on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 750);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var openAyat = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: RuqyahTopicBrowser(
                  resources: [audio('bakara', 'সুরা বাকারা — শায়খ সুদাইস')],
                  onOpenResource: (_) {},
                  onOpenAyat: () => openAyat++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ruqyah-filter-ruqyah-ayat')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ruqyah-filter-ruqyah-self-guide')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('ruqyah-open-ayat')));
      expect(openAyat, 1);
    },
  );
}
