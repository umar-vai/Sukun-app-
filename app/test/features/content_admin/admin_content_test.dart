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

  testWidgets('admin CMS lists canonical state, visibility, and status', (
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

    expect(find.text('Ayatul Kursi'), findsOneWidget);
    expect(find.text('Quran'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
    expect(
      find.widgetWithText(FloatingActionButton, 'New resource'),
      findsOneWidget,
    );
  });

  testWidgets('resource editor exposes direct publish without review actions', (
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
    await tester.scrollUntilVisible(
      find.text('Publish Now'),
      600,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Save Draft'), findsOneWidget);
    expect(find.text('Publish Now'), findsOneWidget);
    expect(find.text('Submit for review'), findsNothing);
    expect(find.text('Verify source'), findsNothing);
  });

  testWidgets('resource preview publishes without verification dialog', (
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
      find.text('Publish Now'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Verify source'), findsNothing);
    expect(find.text('Reject verification'), findsNothing);
    await tester.tap(find.text('Publish Now'));
    await tester.pumpAndSettle();
    expect(find.text('Publish Now resource?'), findsOneWidget);
    expect(find.text('Verify resource?'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Publish Now').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

SaveContentInput _input({
  required String type,
  String? sourceType,
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
  surahNumber: surahNumber,
  ayahNumber: ayahNumber,
  mediaSourceType: mediaSourceType,
  mediaUrl: mediaUrl,
  rightsNote: rightsNote,
);

final class _FakeContentAdminRepository implements ContentAdminRepository {
  const _FakeContentAdminRepository();

  static const item = AdminContentItem(
    id: 'content-1',
    type: 'quran',
    title: 'Ayatul Kursi',
    slug: 'ayatul-kursi',
    visibility: 'public',
    status: 'draft',
    verificationStatus: 'pending',
    surahNumber: 2,
    ayahNumber: 255,
  );

  @override
  Future<AdminContentItem?> getContent(String contentItemId) async => item;

  @override
  Future<List<AdminContentItem>> listContent({String query = ''}) async =>
      const [item];

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
  Future<AdminContentItem> saveContent(SaveContentInput input) async => item;

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
  }) async => item;
}
