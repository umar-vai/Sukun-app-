import 'dart:convert';

import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:uuid/uuid.dart';

/// Public metadata only; never includes third-party audio bytes.
class BookAudioSourceCandidate {
  const BookAudioSourceCandidate({
    required this.id,
    required this.titleBn,
    required this.sourcePage,
    required this.externalMediaUrl,
    required this.bookParagraphIndices,
    required this.requiresContextReview,
  });

  final String id;
  final String titleBn;
  final String sourcePage;
  final String externalMediaUrl;
  final List<int> bookParagraphIndices;
  final bool requiresContextReview;

  String get slug => 'sukun-${id.replaceAll('_', '-')}';

  SaveContentInput draftInput({String? categoryId}) => SaveContentInput(
    type: 'audio',
    categoryId: categoryId,
    title: titleBn,
    titleBn: titleBn,
    slug: slug,
    visibility: 'staff_only',
    status: 'draft',
    requestId: const Uuid().v4(),
    summary: 'রুকইয়াহ অডিও — শুনুন ও প্রয়োজনে পুনরায় চালান।',
    body: 'রুকইয়াহ অডিওটি শুনতে উপরের প্লেয়ার ব্যবহার করুন।',
    sourceType: 'external_reference',
    sourceReference:
        'সেলফ রুকইয়াহ গাইড · paragraph '
        '${bookParagraphIndices.join(', ')} · Ruqyah Support BD',
    sourceUrl: sourcePage,
    mediaSourceType: 'direct_audio_url',
    mediaUrl: externalMediaUrl,
    author: 'Ruqyah Support BD (external)',
    languageCode: 'ar',
    rightsNote:
        'Owner-attested Sukun Life audio authorization, 2026-10-12: '
        'Sukun Life representative confirms license for app playback, '
        'distribution and internal use of all referenced Ruqyah BD audio. '
        'This is the owner\'s authorization statement, not a third-party '
        'signed licensing certificate. Attribution: Ruqyah Support BD.',
  );
}

List<BookAudioSourceCandidate> parseBookAudioCatalog(String encoded) {
  final root = jsonDecode(encoded);
  if (root is! Map<String, dynamic> ||
      root['schema'] != 'sukun.ruqyahbd.external_audio_crosswalk.v1' ||
      root['entries'] is! List) {
    throw const FormatException('Unexpected external audio catalog.');
  }
  final list = root['entries'] as List;
  if (list.isEmpty || list.length > 80) {
    throw const FormatException('Invalid external audio catalog length.');
  }
  final seen = <String>{};
  return List.unmodifiable(
    list.map((value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid external audio item.');
      }
      final id = value['id'];
      final title = value['title_bn'];
      final page = value['original_page'];
      final media = value['media_url'];
      final paragraphIndices = value['book_paragraph_indices'];
      final authorization = root['owner_authorization'];
      if (authorization is! Map<String, dynamic> ||
          authorization['basis'] != 'owner_attested' ||
          authorization['attested_at'] != '2026-10-12') {
        throw const FormatException('Missing Sukun Life audio authorization.');
      }
      if (id is! String ||
          !RegExp(r'^ruqyahbd-[a-z0-9-]+$').hasMatch(id) ||
          !seen.add(id) ||
          title is! String ||
          title.trim().isEmpty ||
          page is! String ||
          media is! String ||
          !const {
            'https://ruqyahbd.org/download',
            'https://ruqyahbd.org/download/others-ruqyah',
          }.contains(page) ||
          Uri.tryParse(media)?.scheme != 'https' ||
          Uri.tryParse(media)?.host != 'files.ruqyahbd.org' ||
          paragraphIndices is! List ||
          paragraphIndices.isEmpty ||
          !paragraphIndices.every((p) => p is int && p >= 1) ||
          value['licensing'] !=
              'owner_attested_for_sukun_life_app_2026_10_12' ||
          value['publication_status'] != 'draft_review_only') {
        throw const FormatException(
          'Untrusted external audio URL or metadata.',
        );
      }
      return BookAudioSourceCandidate(
        id: id,
        titleBn: title,
        sourcePage: page,
        externalMediaUrl: media,
        bookParagraphIndices: List<int>.unmodifiable(
          paragraphIndices.cast<int>(),
        ),
        requiresContextReview:
            value['matching_status'] == 'editorial_context_review',
      );
    }),
  );
}
