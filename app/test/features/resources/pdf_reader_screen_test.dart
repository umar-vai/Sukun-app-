import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:sukun_life/features/resources/presentation/pdf_reader_screen.dart';
import 'package:sukun_life/features/resources/presentation/resource_detail_screen.dart';

void main() {
  const validPdf = LinkedResource(
    id: 'staging-pdf',
    title: 'Original QA-only PDF',
    type: 'pdf',
    mediaSourceType: 'external_pdf',
    mediaUrl: 'https://files.example.test/guide.pdf',
  );

  testWidgets('renders network PDF inside Flutter reader with no auto-exit', (
    tester,
  ) async {
    Uri? requestedUri;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfReaderRendererProvider.overrideWithValue((
            uri,
            controller,
            params,
            key,
            fontManager,
          ) {
            requestedUri = uri;
            return const Center(child: Text('EMBEDDED PDF PAGE'));
          }),
        ],
        child: const MaterialApp(home: PdfReaderScreen(resource: validPdf)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('পিডিএফ পড়ুন'), findsOneWidget);
    expect(find.text('Original QA-only PDF'), findsOneWidget);
    expect(find.text('EMBEDDED PDF PAGE'), findsOneWidget);
    expect(requestedUri, Uri.parse('https://files.example.test/guide.pdf'));
    expect(find.byTooltip('বড় করুন'), findsOneWidget);
    expect(find.byTooltip('ছোট করুন'), findsOneWidget);
    expect(find.byTooltip('আবার লোড করুন'), findsOneWidget);
    expect(find.text('পৃষ্ঠা লোড হচ্ছে…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bengali title opts into missing-font recovery only', (
    tester,
  ) async {
    const bengali = LinkedResource(
      id: 'bn-doc',
      title: 'সেলফ রুকইয়াহ গাইড',
      type: 'pdf',
      mediaSourceType: 'external_pdf',
      mediaUrl: 'https://files.example.test/guide.pdf',
    );
    bool? hadFontManager;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfReaderRendererProvider.overrideWithValue((
            uri,
            controller,
            params,
            key,
            fontManager,
          ) {
            hadFontManager = fontManager != null;
            return const Text('INLINE BENGALI READER');
          }),
        ],
        child: const MaterialApp(home: PdfReaderScreen(resource: bengali)),
      ),
    );
    await tester.pumpAndSettle();
    expect(hadFontManager, isTrue);
    expect(find.text('INLINE BENGALI READER'), findsOneWidget);
  });

  testWidgets('retry reconstructs the reader without redirecting to browser', (
    tester,
  ) async {
    final keys = <Key>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfReaderRendererProvider.overrideWithValue((
            uri,
            controller,
            params,
            key,
            fontManager,
          ) {
            keys.add(key);
            return const Text('INLINE READER');
          }),
        ],
        child: const MaterialApp(home: PdfReaderScreen(resource: validPdf)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('আবার লোড করুন'));
    await tester.pumpAndSettle();
    expect(keys.length, greaterThanOrEqualTo(2));
    expect(keys.first, isNot(keys.last));
    expect(find.text('INLINE READER'), findsOneWidget);
  });

  testWidgets('rejects insecure PDF links in reader without network load', (
    tester,
  ) async {
    const unsafe = LinkedResource(
      id: 'unsafe',
      title: 'Unsafe PDF',
      type: 'pdf',
      mediaSourceType: 'external_pdf',
      mediaUrl: 'http://files.example.test/guide.pdf',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfReaderRendererProvider.overrideWithValue(
            (uri, controller, params, key, fontManager) =>
                const Text('SHOULD NEVER LOAD'),
          ),
        ],
        child: const MaterialApp(home: PdfReaderScreen(resource: unsafe)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('সঠিক পিডিএফ লিংক পাওয়া যায়নি'), findsOneWidget);
    expect(find.text('SHOULD NEVER LOAD'), findsNothing);
  });

  testWidgets('shows PDF-specific, safe recovery guidance on load failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppErrorState(
            message:
                'পিডিএফটি অ্যাপের মধ্যে পড়া যাচ্ছে না। '
                'বাহিরের সার্ভারে সরাসরি PDF ফাইল ও '
                'Browser CORS অনুমতি থাকতে হবে।',
            showSafeMessage: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Browser CORS অনুমতি থাকতে হবে'),
      findsOneWidget,
    );
  });

  testWidgets('PDF detail button opens internal viewer, not a new tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resourcesRepositoryProvider.overrideWithValue(_PdfQaRepository()),
          pdfReaderRendererProvider.overrideWithValue(
            (uri, controller, params, key) => const Text('PDF IS INSIDE SUKUN'),
          ),
        ],
        child: const MaterialApp(
          home: ResourceDetailScreen(resourceId: 'staging-pdf'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('পিডিএফ খুলুন'), findsOneWidget);

    await tester.tap(find.text('পিডিএফ খুলুন'));
    await tester.pumpAndSettle();
    expect(find.text('পিডিএফ পড়ুন'), findsOneWidget);
    expect(find.text('PDF IS INSIDE SUKUN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _PdfQaRepository implements ResourcesRepository {
  @override
  Future<ContentResource?> getResource(String resourceId) async =>
      const ContentResource(
        id: 'staging-pdf',
        type: 'pdf',
        title: 'Original QA-only PDF',
        visibility: 'public',
        status: 'published',
        mediaSourceType: 'external_pdf',
        mediaUrl: 'https://files.example.test/guide.pdf',
      );

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) async => const [];

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
