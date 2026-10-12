import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/domain/private_resource_draft_batch.dart';
import 'package:uuid/uuid.dart';

/// Repairs ONLY a book-sourced, still-private, *heading-only* CMS draft.
/// Never overwrites substantive editorial work or touches published content.
/// The normal authenticated CMS save RPC enforces Super Admin on the server.
SaveContentInput? prepareHeadingOnlySourceRepair({
  required AdminContentItem existing,
  required PrivateResourceDraft candidate,
}) {
  final input = candidate.input;
  final existingBody = existing.body?.trim() ?? '';
  final title = existing.titleBn?.trim().isNotEmpty == true
      ? existing.titleBn!.trim()
      : existing.title.trim();
  final bareBody = existingBody
      .replaceFirst(RegExp(r'^[০-৯0-9]+[.)।]\s*'), '')
      .trim();
  final replacement = input.body?.trim() ?? '';
  if (existing.status != 'draft' ||
      existing.visibility != 'staff_only' ||
      existing.type != input.type ||
      existing.slug != input.slug ||
      existing.sourceType != 'human_provided_book' ||
      input.sourceType != 'human_provided_book' ||
      existing.sourceReference != input.sourceReference ||
      !(existing.rightsNote?.contains('Sukun Life owner attested') ?? false) ||
      !candidate.sourceId.startsWith('SRG2024-') ||
      !(bareBody.isEmpty || bareBody == title) ||
      replacement.length <= existingBody.length + 60 ||
      !replacement.contains(title)) {
    return null;
  }

  return SaveContentInput(
    contentItemId: existing.id,
    type: existing.type,
    title: existing.title,
    titleBn: existing.titleBn,
    slug: existing.slug,
    categoryId: existing.categoryId,
    parentContentId: existing.parentContentId,
    visibility: 'staff_only',
    status: 'draft',
    requestId: const Uuid().v4(),
    summary: input.summary,
    body: replacement,
    arabicText: existing.arabicText ?? input.arabicText,
    banglaText: existing.banglaText ?? input.banglaText,
    transliteration: existing.transliteration ?? input.transliteration,
    translation: existing.translation,
    referenceText: existing.referenceText,
    sourceType: existing.sourceType,
    sourceReference: existing.sourceReference,
    sourceUrl: existing.sourceUrl,
    sourceEdition: existing.sourceEdition,
    translationSource: existing.translationSource,
    surahNumber: existing.surahNumber,
    surahName: existing.surahName,
    surahNameBn: existing.surahNameBn,
    ayahNumber: existing.ayahNumber,
    ayahEndNumber: existing.ayahEndNumber,
    collectionName: existing.collectionName,
    bookName: existing.bookName,
    hadithNumber: existing.hadithNumber,
    narrator: existing.narrator,
    grade: existing.grade,
    author: existing.author,
    publisher: existing.publisher,
    chapterNumber: existing.chapterNumber,
    languageCode: existing.languageCode,
    rightsNote: existing.rightsNote,
    thumbnailUrl: existing.thumbnailUrl,
    mediaSourceType: existing.mediaSourceType,
    mediaUrl: existing.mediaUrl,
    youtubeVideoId: existing.youtubeVideoId,
  );
}
