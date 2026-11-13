import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_repository.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/presentation/admin_content_list_screen.dart';
import 'package:sukun_life/features/content_admin/presentation/admin_content_editor_screen.dart';

void main() {
  test('Ayat collection validation rejects unsafe or ambiguous input', () {
    expect(
      const SaveContentCollectionInput(
        type: 'selected_ayat',
        title: 'Selected Ayat',
        slug: 'selected-ayat',
        visibility: 'public',
        contentItemIds: [],
        requestId: 'request',
      ).validate(),
      'Select at least one Ayah.',
    );
    expect(
      const SaveContentCollectionInput(
        type: 'ruqyah_ayat',
        title: 'Ruqyah Ayat',
        slug: 'ruqyah-ayat',
        visibility: 'assigned_only',
        contentItemIds: ['ayah-1'],
        requestId: 'request',
      ).validate(),
      'Collections can be public or patient-only.',
    );
  });

  test(
    'canonical validation rejects AI source and invalid Quran reference',
    () {
      final aiSource = _input(
        type: 'quran',
        sourceType: 'generative_ai',
        surahNumber: 2,
        ayahNumber: 255,
      );
      expect(aiSource.validate(), contains('cannot be AI-generated'));

      final invalidReference = _input(type: 'quran', surahNumber: 0);
      expect(invalidReference.validate(), contains('valid Surah and Ayah'));
    },
  );

  test('external media validation requires a secure URL or YouTube ID', () {
    expect(
      _input(type: 'audio', mediaSourceType: 'direct_audio_url').validate(),
      contains('HTTPS URL'),
    );
    expect(
      _input(type: 'video', mediaSourceType: 'youtube').validate(),
      contains('video ID'),
    );
  });

  test('external media no longer needs a rights or licensing note', () {
    expect(
      _input(
        type: 'audio',
        mediaSourceType: 'direct_audio_url',
        mediaUrl: 'https://cdn.example.test/audio.mp3',
      ).validate(),
      isNull,
    );
    expect(
      _input(
        type: 'audio',
        mediaSourceType: 'direct_audio_url',
        mediaUrl: 'https://cdn.example.test/audio.mp3',
      ).publicationValidationError(),
      isNull,
    );
  });

  test('one-step publishing needs no source fields, only the Arabic text', () {
    final withoutArabic = _input(type: 'quran', surahNumber: 25, ayahNumber: 1);
    expect(withoutArabic.validate(), isNull);
    expect(withoutArabic.publicationValidationError(), contains('Arabic text'));

    final withoutSource = _input(
      type: 'quran',
      arabicText: 'fixture Arabic text',
      surahNumber: 25,
      ayahNumber: 1,
      status: 'published',
    );
    expect(withoutSource.validate(), isNull);
    expect(withoutSource.publicationValidationError(), isNull);
  });

  test('publication validation accepts complete canonical metadata', () {
    final input = _input(
      type: 'quran',
      sourceType: 'licensed_publication',
      sourceReference: 'Approved Quran 25:1',
      sourceEdition: 'Approved edition',
      arabicText: 'fixture sourced Arabic text',
      surahNumber: 25,
      ayahNumber: 1,
    );

    expect(input.validate(), isNull);
    expect(input.publicationValidationError(), isNull);
  });

  test('simple resource choices generate the correct backend types', () {
    expect(AdminResourceKind.quranAyah.contentType, 'quran');
    expect(AdminResourceKind.hadith.contentType, 'hadith');
    expect(AdminResourceKind.quranAudio.contentType, 'audio');
    expect(AdminResourceKind.quranAudio.mediaSourceType, 'direct_audio_url');
    expect(AdminResourceKind.ruqyahAudio.contentType, 'audio');
    expect(AdminResourceKind.ruqyahAudio.mediaSourceType, 'direct_audio_url');
    expect(AdminResourceKind.bookPdf.contentType, 'pdf');
    expect(AdminResourceKind.bookPdf.mediaSourceType, 'external_pdf');
    expect(AdminResourceKind.video.contentType, 'video');
    expect(AdminResourceKind.duaAzkar.contentType, 'dua');
    expect(AdminResourceKind.articleGuide.contentType, 'article');
  });

  test(
    'blog uses existing secured article type, separate from editorial shelf',
    () {
      expect(AdminResourceKind.blog.contentType, 'article');
      expect(AdminResourceKind.blog.mediaSourceType, isNull);
      const blog = AdminContentItem(
        id: 'blog-test',
        type: 'article',
        title: 'An editor-written blog',
        slug: 'blog-first-post-12345678',
        visibility: 'public',
        status: 'draft',
        verificationStatus: 'not_required',
      );
      const article = AdminContentItem(
        id: 'article-test',
        type: 'article',
        title: 'A resource article',
        slug: 'article-first-post-12345678',
        visibility: 'public',
        status: 'draft',
        verificationStatus: 'not_required',
      );
      expect(resourceKindForItem(blog), AdminResourceKind.blog);
      expect(resourceKindForItem(article), AdminResourceKind.articleGuide);
    },
  );

  test('internal media and slug fields are inferred safely', () {
    expect(
      inferYoutubeVideoId('https://www.youtube.com/watch?v=abc123'),
      'abc123',
    );
    expect(inferYoutubeVideoId('https://youtu.be/xyz789'), 'xyz789');
    expect(
      generatedResourceSlug('Morning Ruqyah Audio', 'ABCDEF12-more'),
      'morning-ruqyah-audio-abcdef12',
    );
    expect(generatedResourceSlug('দুআ', 'ABCDEF12-more'), 'resource-abcdef12');
  });

  testWidgets('resource home lists only types, no review or import extras', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAdminRepositoryProvider.overrideWithValue(
            const _FakeContentAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: AdminContentListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('কুরআনের আয়াত'), findsOneWidget);
    for (final removed in const [
      'সংরক্ষিত খসড়া',
      'যাচাইয়ের অপেক্ষায়',
      'আয়াতের সংগ্রহ পরিচালনা',
      'উন্নত সেটিংস',
    ]) {
      expect(find.text(removed), findsNothing);
    }

    await tester.tap(find.text('কুরআনের আয়াত'));
    await tester.pumpAndSettle();
    expect(find.text('যোগ করুন'), findsOneWidget);
    expect(find.text('Ayatul Kursi'), findsOneWidget);
    // The fixture is a legacy unpublished row, so it shows as hidden.
    expect(find.text('লুকানো'), findsWidgets);

    await tester.tap(find.text('প্রকাশিত'));
    await tester.pumpAndSettle();
    expect(find.text('Ayatul Kursi'), findsNothing);
  });

  testWidgets('category card opens matching preselected editor form', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/admin/content',
      routes: [
        GoRoute(
          path: '/admin/content',
          builder: (context, state) => const AdminContentListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => AdminContentEditorScreen(
                initialKind: state.extra as AdminResourceKind?,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAdminRepositoryProvider.overrideWithValue(
            const _FakeContentAdminRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('হাদিস'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('যোগ করুন'));
    await tester.pumpAndSettle();

    expect(find.text('নতুন উপকরণ যোগ করুন'), findsOneWidget);
    expect(find.text('কোন ধরনের উপকরণ?'), findsNothing);
    expect(find.text('হাদিসের কিতাব *'), findsOneWidget);
  });

  testWidgets('resource editor offers nine clear choices including Blog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAdminRepositoryProvider.overrideWithValue(
            const _FakeContentAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: AdminContentEditorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in const [
      "কুরআনের আয়াত",
      'হাদিস',
      "কুরআন অডিও",
      'রুকইয়াহ অডিও',
      'বই ও পিডিএফ',
      'ভিডিও',
      'দোয়া ও যিকর',
      'আর্টিকেল',
      'ব্লগ লিখুন',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Slug'), findsNothing);
    expect(find.text('Media type'), findsNothing);
    expect(find.text('Visibility'), findsNothing);
  });

  for (final scenario in const <(String, String)>[
    ("কুরআনের আয়াত", 'আরবি লেখা *'),
    ('হাদিস', 'হাদিসের কিতাব *'),
    ("কুরআন অডিও", 'অডিও লিংক *'),
    ('রুকইয়াহ অডিও', 'অডিও লিংক *'),
    ('বই ও পিডিএফ', 'পিডিএফ লিংক *'),
    ('ভিডিও', 'ভিডিও লিংক *'),
    ('দোয়া ও যিকর', 'আরবি *'),
    ('আর্টিকেল', 'সম্পূর্ণ লেখা *'),
    ('ব্লগ লিখুন', 'ব্লগের সম্পূর্ণ লেখা *'),
  ]) {
    testWidgets('${scenario.$1} opens its tailored form', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentAdminRepositoryProvider.overrideWithValue(
              const _FakeContentAdminRepository(),
            ),
          ],
          child: const MaterialApp(home: AdminContentEditorScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(scenario.$1),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(scenario.$1));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(scenario.$2),
        350,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(scenario.$2), findsOneWidget);
      expect(find.text('Slug'), findsNothing);
      expect(find.text('Media source type'), findsNothing);
      expect(find.text('Request ID'), findsNothing);
    });
  }

  testWidgets('Quran form has no source, licence or draft steps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAdminRepositoryProvider.overrideWithValue(
            const _FakeContentAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: AdminContentEditorScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("কুরআনের আয়াত"));
    await tester.pumpAndSettle();

    expect(find.text('আরবি লেখা *'), findsOneWidget);
    expect(find.text('বাংলা অনুবাদ *'), findsOneWidget);
    expect(find.text('সূরা *'), findsOneWidget);
    expect(find.text('কারা দেখতে পারবেন?'), findsOneWidget);
    expect(find.text('প্রকাশ করুন'), findsOneWidget);
    for (final removed in const [
      'অনুমোদিত তথ্যসূত্র *',
      'অতিরিক্ত সেটিংস',
      'খসড়া সংরক্ষণ করুন',
      'যাচাইয়ের জন্য পাঠান',
      'আগে দেখে নিন',
      'Slug',
      'Request ID',
    ]) {
      expect(find.text(removed), findsNothing);
    }
  });

  testWidgets('editing saves once and publishes immediately', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _savedInputs.clear();
    _transitions.clear();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAdminRepositoryProvider.overrideWithValue(
            const _FakeContentAdminRepository(),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const AdminContentEditorScreen(contentItemId: 'content-1'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('আপডেট করুন'), findsOneWidget);
    await tester.tap(find.text('আপডেট করুন'));
    await tester.pumpAndSettle();

    expect(_savedInputs, hasLength(1));
    expect(_savedInputs.single.status, 'published');
    expect(_savedInputs.single.contentItemId, 'content-1');
    // Source fields saved earlier are kept untouched, not dropped.
    expect(_savedInputs.single.sourceReference, 'Approved Quran 2:255');
    expect(_transitions, isEmpty);
    expect(find.text('পরিবর্তন প্রকাশিত হয়েছে।'), findsOneWidget);
  });
}

SaveContentInput _input({
  required String type,
  String? sourceType,
  String? sourceReference,
  String? sourceEdition,
  String? arabicText,
  int? surahNumber,
  int? ayahNumber,
  String? mediaSourceType,
  String? mediaUrl,
  String? rightsNote,
  String status = 'draft',
}) => SaveContentInput(
  type: type,
  title: 'Fixture',
  slug: 'fixture',
  visibility: 'staff_only',
  status: status,
  requestId: 'request',
  sourceType: sourceType,
  sourceReference: sourceReference,
  sourceEdition: sourceEdition,
  arabicText: arabicText,
  surahNumber: surahNumber,
  ayahNumber: ayahNumber,
  mediaSourceType: mediaSourceType,
  mediaUrl: mediaUrl,
  rightsNote: rightsNote,
);

final _savedInputs = <SaveContentInput>[];
final _transitions = <String>[];

final class _FakeContentAdminRepository implements ContentAdminRepository {
  const _FakeContentAdminRepository({this.content = item});

  final AdminContentItem content;

  static const item = AdminContentItem(
    id: 'content-1',
    type: 'quran',
    title: 'Ayatul Kursi',
    slug: 'ayatul-kursi',
    visibility: 'public',
    status: 'draft',
    verificationStatus: 'pending',
    arabicText: 'fixture sourced Arabic text',
    banglaText: 'fixture Bangla translation',
    sourceType: 'licensed_publication',
    sourceReference: 'Approved Quran 2:255',
    sourceEdition: 'Approved edition',
    surahNumber: 2,
    ayahNumber: 255,
  );

  @override
  Future<AdminContentItem?> getContent(String contentItemId) async => content;

  @override
  Future<List<AdminContentItem>> listContent({String query = ''}) async => [
    content,
  ];

  @override
  Future<List<ContentCategory>> listCategories() async => const [];

  @override
  Future<List<ContentReview>> listReviews(String contentItemId) async =>
      const [];

  @override
  Future<List<AdminContentCollection>> listCollections() async => const [];

  @override
  Future<List<ContentCategory>> installStandardResourceTaxonomy({
    required String requestId,
  }) async => const [];

  @override
  Future<AdminContentCollection> saveCollection(
    SaveContentCollectionInput input,
  ) => throw UnimplementedError();

  @override
  Future<AdminContentCollection> transitionCollection({
    required String collectionId,
    required String transition,
    required String requestId,
  }) => throw UnimplementedError();

  @override
  Future<AdminContentItem> saveContent(SaveContentInput input) async {
    _savedInputs.add(input);
    return content;
  }

  @override
  Future<ContentCategory> saveCategory({
    required String name,
    required String slug,
    required String requestId,
    String? categoryId,
    String? parentId,
    String? nameBn,
    int sortOrder = 0,
    bool isActive = true,
  }) => throw UnimplementedError();

  @override
  Future<AdminContentItem> transitionContent({
    required String contentItemId,
    required String transition,
    required String requestId,
    String? notes,
  }) async {
    _transitions.add(transition);
    return content;
  }
}
