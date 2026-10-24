import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';
import 'package:sukun_life/features/resources/presentation/resource_category_screen.dart';
import 'package:sukun_life/features/resources/presentation/audio_player_screen.dart';

void main() {
  testWidgets('audio list tap goes directly to the full player', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resourcesRepositoryProvider.overrideWithValue(
            _SearchResourcesRepository(playableAudio: true),
          ),
        ],
        child: MaterialApp(
          home: ResourceCategoryScreen(
            section: resourceSectionBySlug('audio')!,
            loadAudioResource: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Result for all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AudioPlayerScreen), findsOneWidget);
    expect(find.text('অডিও উৎস'), findsNothing);
    expect(find.text('অডিও শুনুন'), findsNothing);
    expect(find.text('উপকরণটি খুলুন'), findsNothing);
    expect(find.text('শোনার গতি'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category hides outdated results while search is debouncing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _SearchResourcesRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [resourcesRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: ResourceCategoryScreen(
            section: resourceSectionBySlug('audio')!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Result for all'), findsOneWidget);
    expect(repository.calls, 1);

    await tester.enterText(find.byType(TextField), 'first');
    await tester.pump();
    expect(find.text('Result for all'), findsNothing);
    expect(find.text('অনুসন্ধান করা হচ্ছে…'), findsOneWidget);
    expect(repository.calls, 1);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Result for first'), findsOneWidget);
    expect(repository.calls, 2);

    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump();
    expect(find.text('Result for first'), findsNothing);
    expect(find.text('অনুসন্ধান করা হচ্ছে…'), findsOneWidget);
    expect(repository.calls, 2);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Result for second'), findsOneWidget);
    expect(repository.calls, 3);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Result for second'), findsNothing);
    expect(find.text('Result for all'), findsOneWidget);
    expect(repository.calls, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('merged library separates books and articles on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _LibraryTabsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [resourcesRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: ResourceCategoryScreen(
            section: resourceSectionBySlug('books-articles')!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('books-articles-inner-tabs')), findsOneWidget);
    expect(find.text('বই'), findsWidgets);
    expect(find.text('আর্টিকেল'), findsOneWidget);
    expect(find.text('প্রকাশিত বই'), findsOneWidget);
    expect(find.text('প্রকাশিত আর্টিকেল'), findsNothing);
    expect(find.text('ব্লগ পোস্ট'), findsNothing);
    expect(repository.requestTypes.last, {'book', 'book_chapter', 'pdf'});

    await tester.tap(find.text('আর্টিকেল'));
    await tester.pumpAndSettle();
    expect(repository.requestTypes.last, {'article', 'guide'});
    expect(find.text('প্রকাশিত বই'), findsNothing);
    expect(find.text('প্রকাশিত আর্টিকেল'), findsOneWidget);
    expect(find.text('প্রকাশিত গাইড'), findsOneWidget);
    expect(find.text('ব্লগ পোস্ট'), findsNothing);

    await tester.tap(find.text('বই').first);
    await tester.pumpAndSettle();
    expect(find.text('প্রকাশিত বই'), findsOneWidget);
    expect(find.text('প্রকাশিত আর্টিকেল'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('merged library search is scoped to the active tab', (
    tester,
  ) async {
    final repository = _LibraryTabsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [resourcesRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: ResourceCategoryScreen(
            section: resourceSectionBySlug('books-articles')!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'প্রকাশিত');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(repository.queries.last, 'প্রকাশিত');
    expect(repository.requestTypes.last, {'book', 'book_chapter', 'pdf'});
    expect(find.text('প্রকাশিত বই'), findsOneWidget);
    expect(find.text('প্রকাশিত আর্টিকেল'), findsNothing);

    await tester.tap(find.text('আর্টিকেল'));
    await tester.pumpAndSettle();
    expect(repository.queries.last, 'প্রকাশিত');
    expect(repository.requestTypes.last, {'article', 'guide'});
    expect(find.text('প্রকাশিত আর্টিকেল'), findsOneWidget);
    expect(find.text('প্রকাশিত বই'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final class _SearchResourcesRepository implements ResourcesRepository {
  _SearchResourcesRepository({this.playableAudio = false});

  final bool playableAudio;
  int calls = 0;

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async {
    calls++;
    if (!types.contains('audio')) {
      throw StateError('Expected the audio category filter.');
    }
    return [
      ContentResource(
        id: 'qa-result',
        type: 'audio',
        title: 'Result for ${query.isEmpty ? 'all' : query}',
        mediaSourceType: playableAudio ? 'direct_audio_url' : null,
        mediaUrl: playableAudio
            ? 'https://files.ruqyahbd.org/audio/example.mp3'
            : null,
        visibility: 'public',
        status: 'published',
      ),
    ];
  }

  @override
  Future<ContentResource?> getResource(String resourceId) async => null;

  @override
  Future<List<QuranSurahSummary>> browseSurahs() async => const [];

  @override
  Future<List<ContentResource>> browseSurah(int surahNumber) async => const [];

  @override
  Future<List<ResourceTopic>> browseTopics({
    required Set<String> types,
    Set<String> categoryPrefixes = const {},
  }) async => const [];

  @override
  Future<List<ContentCollection>> browseCollections({
    Set<String> types = const {},
  }) async => const [];

  @override
  Future<ContentCollectionDetails?> getCollection(String collectionId) async =>
      null;
}

final class _LibraryTabsRepository implements ResourcesRepository {
  final List<Set<String>> requestTypes = [];
  final List<String> queries = [];

  static const resources = <ContentResource>[
    ContentResource(
      id: 'book-1',
      slug: 'library-book',
      type: 'book',
      title: 'প্রকাশিত বই',
      visibility: 'public',
      status: 'published',
    ),
    ContentResource(
      id: 'article-1',
      slug: 'library-article',
      type: 'article',
      title: 'প্রকাশিত আর্টিকেল',
      visibility: 'public',
      status: 'published',
    ),
    ContentResource(
      id: 'guide-1',
      slug: 'library-guide',
      type: 'guide',
      title: 'প্রকাশিত গাইড',
      visibility: 'public',
      status: 'published',
    ),
    ContentResource(
      id: 'blog-1',
      slug: 'blog-public-post',
      type: 'article',
      title: 'ব্লগ পোস্ট',
      visibility: 'public',
      status: 'published',
    ),
  ];

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async {
    requestTypes.add(Set<String>.of(types));
    queries.add(query);
    return resources
        .where(
          (item) =>
              types.contains(item.type) &&
              (query.isEmpty || item.title.contains(query)),
        )
        .toList(growable: false);
  }

  @override
  Future<ContentResource?> getResource(String resourceId) async => null;

  @override
  Future<List<QuranSurahSummary>> browseSurahs() async => const [];

  @override
  Future<List<ContentResource>> browseSurah(int surahNumber) async => const [];

  @override
  Future<List<ResourceTopic>> browseTopics({
    required Set<String> types,
    Set<String> categoryPrefixes = const {},
  }) async => const [];

  @override
  Future<List<ContentCollection>> browseCollections({
    Set<String> types = const {},
  }) async => const [];

  @override
  Future<ContentCollectionDetails?> getCollection(String collectionId) async =>
      null;
}
