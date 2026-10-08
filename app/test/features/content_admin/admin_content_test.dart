import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_repository.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/presentation/admin_content_list_screen.dart';
import 'package:sukun_life/features/content_admin/presentation/admin_content_editor_screen.dart';
import 'package:sukun_life/features/content_admin/presentation/admin_content_preview_screen.dart';

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

  test('external media validation requires rights metadata', () {
    expect(
      _input(
        type: 'audio',
        mediaSourceType: 'direct_audio_url',
        mediaUrl: 'https://cdn.example.test/audio.mp3',
      ).validate(),
      contains('rights or licensing note'),
    );
    expect(
      _input(
        type: 'audio',
        mediaSourceType: 'direct_audio_url',
        mediaUrl: 'https://cdn.example.test/audio.mp3',
        rightsNote: 'Licensed by the publisher.',
      ).validate(),
      isNull,
    );
  });

  test('publication validation explains missing canonical source fields', () {
    final input = _input(
      type: 'quran',
      surahNumber: 25,
      ayahNumber: 1,
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'https://cdn.example.test/recitation.mp3',
      rightsNote: 'Licensed recitation.',
    );

    expect(input.validate(), isNull);
    expect(
      input.publicationValidationError(),
      allOf(
        contains('approved source format'),
        contains('source name or reference'),
        contains('edition or version'),
        contains('sourced Arabic text'),
        contains('choose Qur’an / Surah Audio'),
      ),
    );
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

  testWidgets('category-first CMS keeps saved drafts in their own tab', (
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

    expect(find.text('সংরক্ষিত খসড়া'), findsOneWidget);
    expect(find.text('যাচাইয়ের অপেক্ষায়'), findsOneWidget);
    expect(find.text('কুরআনের আয়াত'), findsOneWidget);
    expect(find.text('Ayatul Kursi'), findsNothing);
    expect(find.text('New resource'), findsNothing);

    await tester.tap(find.text('কুরআনের আয়াত'));
    await tester.pumpAndSettle();
    expect(find.text('নতুন কুরআনের আয়াত যোগ করুন'), findsOneWidget);
    expect(find.text('Ayatul Kursi'), findsOneWidget);
    expect(find.text('খসড়া'), findsWidgets);

    await tester.tap(find.text('প্রকাশিত'));
    await tester.pumpAndSettle();
    expect(find.text('Ayatul Kursi'), findsNothing);

    await tester.tap(find.text('খসড়া').first);
    await tester.pumpAndSettle();
    expect(find.text('Ayatul Kursi'), findsOneWidget);

    await tester.tap(find.text('সব বিভাগে ফিরে যান'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('সংরক্ষিত খসড়া'));
    await tester.pumpAndSettle();
    expect(find.text('সব বিভাগের খসড়া'), findsOneWidget);
    expect(find.text('Ayatul Kursi'), findsOneWidget);
  });

  testWidgets('resource editor starts with eight plain-language choices', (
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
      'রুকইয়াহ অডিও",
      'বই ও পিডিএফ",
      'ভিডিও",
      'দোয়া ও যিকর",
      'লেখা ও নির্দেশিকা",
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
    ('রুকইয়াহ অডিও", 'অডিও লিংক *'),
    ('বই ও পিডিএফ", 'পিডিএফ লিংক *'),
    ('ভিডিও", 'ভিডিও লিংক *'),
    ('দোয়া ও যিকর", 'আরবি *'),
    ('লেখা ও নির্দেশিকা", 'সম্পূর্ণ লেখা *'),
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

  testWidgets('Quran form shows only human-facing required fields', (
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
    await tester.tap(find.text("কুরআনের আয়াত"));
    await tester.pumpAndSettle();

    expect(find.text('আরবি লেখা *'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('বাংলা অনুবাদ *'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('সূরা *'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('অনুমোদিত উৎস *'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('অতিরিক্ত সেটিংস'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('খসড়া সংরক্ষণ করুন'), findsOneWidget);
    expect(find.text('যাচাইয়ের জন্য পাঠান'), findsOneWidget);
    expect(find.text('Slug'), findsNothing);
    expect(find.text('Request ID'), findsNothing);
    expect(find.text('Media type'), findsNothing);
  });

  testWidgets('canonical preview requires review before verification', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAdminRepositoryProvider.overrideWithValue(
            const _FakeContentAdminRepository(),
          ),
        ],
        child: const MaterialApp(
          home: AdminContentPreviewScreen(contentItemId: 'content-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Submit for Review'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Publish'), findsNothing);
    expect(find.text('Verify Source'), findsNothing);
    await tester.tap(find.text('Submit for Review'));
    await tester.pumpAndSettle();
    expect(find.text('Submit for Review resource?'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Submit for Review').last,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('resource preview explains incomplete canonical publication', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAdminRepositoryProvider.overrideWithValue(
            const _FakeContentAdminRepository(
              content: _FakeContentAdminRepository.incompleteQuranAudio,
            ),
          ),
        ],
        child: const MaterialApp(
          home: AdminContentPreviewScreen(contentItemId: 'content-2'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Submit for Review'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('Submit for Review'));
    await tester.pump();

    expect(find.textContaining('approved source format'), findsOneWidget);
    expect(find.textContaining('choose Qur’an / Surah Audio'), findsOneWidget);
    expect(find.text('Submit for Review resource?'), findsNothing);
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
}) => SaveContentInput(
  type: type,
  title: 'Fixture',
  slug: 'fixture',
  visibility: 'staff_only',
  status: 'draft',
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
    sourceType: 'licensed_publication',
    sourceReference: 'Approved Quran 2:255',
    sourceEdition: 'Approved edition',
    surahNumber: 2,
    ayahNumber: 255,
  );

  static const incompleteQuranAudio = AdminContentItem(
    id: 'content-2',
    type: 'quran',
    title: 'Recitation',
    slug: 'recitation',
    visibility: 'public',
    status: 'draft',
    verificationStatus: 'pending',
    surahNumber: 25,
    ayahNumber: 1,
    ayahEndNumber: 25,
    mediaSourceType: 'direct_audio_url',
    mediaUrl: 'https://cdn.example.test/recitation.mp3',
    rightsNote: 'Licensed recitation.',
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
  Future<AdminContentItem> saveContent(SaveContentInput input) async => content;

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
  }) async => content;
}
