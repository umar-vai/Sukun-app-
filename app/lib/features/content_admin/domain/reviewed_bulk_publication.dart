import 'package:sukun_life/features/content_admin/data/content_admin_repository.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:uuid/uuid.dart';

/// Only the publisher-attested, independently reviewable 2024 source catalog
/// and the explicitly authorized audio batch are eligible. Incomplete Qur'an
/// fragments and any private/QA/synthetic content are NEVER bulk-published.
bool canBulkPublishReviewedResource(AdminContentItem item) {
  if (item.status != 'draft' && item.status != 'review') return false;
  if (item.visibility != 'staff_only' && item.visibility != 'public') {
    return false;
  }
  if (item.isCanonical || item.type == 'hadith') return false;
  if (item.slug.startsWith('srg2024-qur-')) return false;
  if (item.title.contains('সূত্র যাচাই প্রয়োজন')) return false;
  if (RegExp(
    r'(^|[-_])(?:qa|test|fixture|sample|synthetic)(?:[-_]|$)',
    caseSensitive: false,
  ).hasMatch(item.slug)) {
    return false;
  }
  if (item.title.toLowerCase().contains('qa test only')) return false;
  if (item.sourceReference?.trim().isNotEmpty != true ||
      item.rightsNote?.trim().isNotEmpty != true) {
    return false;
  }
  if (item.publicationValidationError() != null) return false;

  final approvedBookDraft =
      item.slug.startsWith('srg2024-') &&
      (item.type == 'article' || item.type == 'dua' || item.type == 'amal');
  final approvedAudio =
      item.slug.startsWith('sukun-ruqyahbd-') &&
      item.type == 'audio' &&
      item.mediaSourceType == 'direct_audio_url' &&
      (Uri.tryParse(item.mediaUrl ?? '')?.scheme == 'https');
  return approvedBookDraft || approvedAudio;
}

List<AdminContentItem> reviewedBulkPublishCandidates(
  List<AdminContentItem> items,
) => List.unmodifiable(
  items.where(canBulkPublishReviewedResource).toList(growable: false),
);

class ReviewedBulkPublishResult {
  const ReviewedBulkPublishResult({
    required this.published,
    required this.failed,
    required this.failedTitles,
  });

  final int published;
  final int failed;
  final List<String> failedTitles;
}

/// Called exclusively from the logged-in Super Admin CMS.
/// Every state mutation calls the existing RLS/role-checked RPCs, each of which
/// records a server-side audit event. No service key, SQL impersonation, or
/// privileged client field is involved.
///
/// On a partial network failure, reloading the CMS lets the Super Admin resume
/// a saved public draft or a reviewed item without losing original content.
Future<ReviewedBulkPublishResult> publishReviewedResourceBatch({
  required ContentAdminRepository repository,
  required List<AdminContentItem> candidates,
  required void Function(int processed, int total) onProgress,
}) async {
  final approved = reviewedBulkPublishCandidates(candidates);
  final failures = <String>[];
  var published = 0;
  var processed = 0;
  for (final original in approved) {
    try {
      var item = original;
      if (item.status == 'draft' && item.visibility == 'staff_only') {
        item = await repository.saveContent(
          SaveContentInput(
            contentItemId: item.id,
            type: item.type,
            title: item.title,
            titleBn: item.titleBn,
            slug: item.slug,
            categoryId: item.categoryId,
            parentContentId: item.parentContentId,
            summary: item.summary,
            body: item.body,
            arabicText: item.arabicText,
            banglaText: item.banglaText,
            transliteration: item.transliteration,
            translation: item.translation,
            referenceText: item.referenceText,
            sourceType: item.sourceType,
            sourceReference: item.sourceReference,
            sourceUrl: item.sourceUrl,
            sourceEdition: item.sourceEdition,
            translationSource: item.translationSource,
            surahNumber: item.surahNumber,
            surahName: item.surahName,
            surahNameBn: item.surahNameBn,
            ayahNumber: item.ayahNumber,
            ayahEndNumber: item.ayahEndNumber,
            collectionName: item.collectionName,
            bookName: item.bookName,
            hadithNumber: item.hadithNumber,
            narrator: item.narrator,
            grade: item.grade,
            author: item.author,
            publisher: item.publisher,
            chapterNumber: item.chapterNumber,
            languageCode: item.languageCode,
            rightsNote: item.rightsNote,
            thumbnailUrl: item.thumbnailUrl,
            mediaSourceType: item.mediaSourceType,
            mediaUrl: item.mediaUrl,
            youtubeVideoId: item.youtubeVideoId,
            visibility: 'public',
            status: 'draft',
            requestId: const Uuid().v4(),
          ),
        );
      }
      if (item.status == 'review' && item.visibility != 'public') {
        // Never automatically reclassify previously reviewed private data.
        throw const ContentAdminException(
          'Private reviewed content requires individual review.',
        );
      }
      if (item.status == 'draft') {
        item = await repository.transitionContent(
          contentItemId: item.id,
          transition: 'submit',
          requestId: const Uuid().v4(),
          notes: 'Super Admin reviewed batch: submitted for publication.',
        );
      }
      if (item.status != 'review' || item.visibility != 'public') {
        throw const ContentAdminException('Invalid publication state.');
      }
      final publishedItem = await repository.transitionContent(
        contentItemId: item.id,
        transition: 'publish',
        requestId: const Uuid().v4(),
        notes: 'Super Admin confirmed reviewed Sukun Life resource batch.',
      );
      if (publishedItem.status != 'published' ||
          publishedItem.visibility != 'public') {
        throw const ContentAdminException('Publish was not confirmed.');
      }
      published++;
    } catch (_) {
      // Keep a tally but never show backend exceptions to the UI.
      failures.add(original.titleBn ?? original.title);
    } finally {
      processed++;
      onProgress(processed, approved.length);
    }
  }
  return ReviewedBulkPublishResult(
    published: published,
    failed: failures.length,
    failedTitles: List.unmodifiable(failures),
  );
}
