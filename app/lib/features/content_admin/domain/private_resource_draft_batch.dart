import 'dart:convert';

import 'package:sukun_life/app/config/app_environment.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';

/// Accepts ONLY the staff-only payload produced from the owner-provided book.
/// This is not an AI publishing endpoint and does not grant admin privileges.
class PrivateResourceDraftBatch {
  PrivateResourceDraftBatch._(this.items);

  static const sourceSha256 =
      '8b9af4677cec5c4b8964a431a47c076a7a59e862d91606caede8ad6141257f24';
  static const stagingSupabaseUrl = 'https://qacklgqvxvjjzsimjoip.supabase.co';
  static const maxBytes = 8 * 1024 * 1024;

  final List<PrivateResourceDraft> items;

  /// Production is deliberately blocked even if runtime environment flags
  /// were accidentally set to "staging" while pointing at production.
  static bool mayImport({
    required String environment,
    required String supabaseUrl,
  }) =>
      environment == 'staging' &&
      supabaseUrl == stagingSupabaseUrl &&
      supabaseUrl != AppEnvironment.productionSupabaseUrl;

  static PrivateResourceDraftBatch parse(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
        'Private catalog file is empty or too large.',
      );
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['schema'] != 'sukun.private_admin_draft_payload.v1' ||
        decoded['source_sha256'] != sourceSha256 ||
        decoded['imported'] != false ||
        decoded['published'] != false ||
        decoded['copyright_permission'] != 'user_attested_for_sukun_life_app') {
      throw const FormatException('Unrecognized or unapproved draft catalog.');
    }
    final rows = decoded['entries'];
    if (rows is! List || rows.isEmpty || rows.length > 500) {
      throw const FormatException('Draft catalog item count is invalid.');
    }
    final seen = <String>{};
    final validated = <PrivateResourceDraft>[];
    for (final entry in rows) {
      if (entry is! Map<String, dynamic> ||
          entry['approved_for_patient'] != false ||
          entry['source_resource_id'] is! String ||
          entry['source_category'] is! String ||
          entry['input'] is! Map<String, dynamic>) {
        throw const FormatException('Catalog includes an invalid draft item.');
      }
      final sourceId = entry['source_resource_id'] as String;
      final kind = entry['source_category'] as String;
      final input = entry['input'] as Map<String, dynamic>;
      if (!RegExp(r'^SRG2024-[A-Z]{3}-\d{3}$').hasMatch(sourceId) ||
          !seen.add(sourceId) ||
          !const {
            'dua',
            'quran',
            'amal',
            'ghusl',
            'supplement',
            'ruqyah_guide',
            'prayer_collection',
          }.contains(kind) ||
          input['status'] != 'draft' ||
          input['visibility'] != 'staff_only' ||
          input['slug'] != sourceId.toLowerCase() ||
          input['requestId'] is! String ||
          !RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ).hasMatch(input['requestId'] as String) ||
          (kind == 'quran' && input['type'] != 'article') ||
          (kind != 'quran' &&
              !const {'article', 'dua', 'amal'}.contains(input['type']))) {
        throw FormatException('Unsafe or duplicated resource ID: $sourceId.');
      }
      final draft = SaveContentInput(
        type: _string(input, 'type'),
        title: _string(input, 'title'),
        titleBn: _optional(input, 'titleBn'),
        slug: _string(input, 'slug'),
        visibility: 'staff_only',
        status: 'draft',
        requestId: _string(input, 'requestId'),
        summary: _optional(input, 'summary'),
        body: _optional(input, 'body'),
        arabicText: _optional(input, 'arabicText'),
        banglaText: _optional(input, 'banglaText'),
        transliteration: _optional(input, 'transliteration'),
        referenceText: _string(input, 'referenceText'),
        sourceType: _string(input, 'sourceType'),
        sourceReference: _string(input, 'sourceReference'),
        sourceEdition: _string(input, 'sourceEdition'),
        author: _optional(input, 'author'),
        publisher: _optional(input, 'publisher'),
        rightsNote: _string(input, 'rightsNote'),
        languageCode: _optional(input, 'languageCode'),
      );
      if (draft.validate() != null) {
        throw FormatException('Invalid draft fields: $sourceId.');
      }
      if (draft.sourceType != 'human_provided_book' ||
          !(draft.sourceReference?.contains('সেলফ রুকইয়াহ গাইড') ?? false) ||
          !(draft.rightsNote?.contains('Sukun Life owner attested') ?? false)) {
        throw FormatException('Source or rights check failed: $sourceId.');
      }
      validated.add(
        PrivateResourceDraft(
          sourceId: sourceId,
          sourceCategory: kind,
          needsCanonicalReview: entry['needs_canonical_review'] == true,
          needsClinicalReview: entry['needs_clinical_review'] == true,
          input: draft,
        ),
      );
    }
    return PrivateResourceDraftBatch._(List.unmodifiable(validated));
  }

  static String _string(Map<String, dynamic> input, String key) {
    final value = input[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing required draft field: $key.');
    }
    return value.trim();
  }

  static String? _optional(Map<String, dynamic> input, String key) {
    final value = input[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('Invalid field: $key.');
    return value.trim().isEmpty ? null : value.trim();
  }
}

class PrivateResourceDraft {
  const PrivateResourceDraft({
    required this.sourceId,
    required this.sourceCategory,
    required this.needsCanonicalReview,
    required this.needsClinicalReview,
    required this.input,
  });

  final String sourceId;
  final String sourceCategory;
  final bool needsCanonicalReview;
  final bool needsClinicalReview;
  final SaveContentInput input;
}
