import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/domain/selected_draft_actions.dart';
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
  if (item.type == 'article' && item.arabicText?.trim().isNotEmpty == true) {
    return false;
  }
  if (item.sourceReference?.trim().isNotEmpty != true ||
      item.rightsNote?.trim().isNotEmpty != true) {
    return false;
  }
  if (item.publicationValidationError() != null) return false;

  final approvedBookDraft =
      item.slug.startsWith('srg2024-') &&
      (item.type == 'article' || item.type == 'dua' || item.type == 'amal') &&
      (item.rightsNote?.startsWith(
            'Sukun Life owner attested app-use rights on 2026-10-12.',
          ) ??
          false);
  final uri = Uri.tryParse(item.mediaUrl ?? '');
  final approvedAudio =
      item.slug.startsWith('sukun-ruqyahbd-') &&
      item.type == 'audio' &&
      item.mediaSourceType == 'direct_audio_url' &&
      uri?.scheme == 'https' &&
      uri?.host == 'files.ruqyahbd.org' &&
      (uri?.path.startsWith('/audio/') ?? false) &&
      (item.rightsNote?.startsWith(
            'Owner-attested Sukun Life audio authorization (2026-10-12).',
          ) ??
          false);
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

/// Uses one authorized database RPC. The SQL function obtains fresh
/// row locks, checks publisher-specific provenance and publishes each item
/// atomically with server-side audit logs. No stale client-side saves.
Future<ReviewedBulkPublishResult> publishReviewedResourceBatch({
  required SupabaseClient client,
  required List<AdminContentItem> candidates,
  required void Function(int processed, int total) onProgress,
}) async {
  final approved = reviewedBulkPublishCandidates(candidates);
  if (approved.isEmpty) {
    return const ReviewedBulkPublishResult(
      published: 0,
      failed: 0,
      failedTitles: [],
    );
  }
  var processed = 0;
  var published = 0;
  var failed = 0;
  for (final chunk in splitDraftBatch(approved)) {
    final response = await client.rpc(
      'publish_reviewed_resource_batch',
      params: {
        'p_content_item_ids': chunk.map((item) => item.id).toList(),
        'p_request_id': const Uuid().v4(),
      },
    );
    final result = response as Map<String, dynamic>;
    published += result['published'] as int? ?? 0;
    failed += result['failed'] as int? ?? 0;
    // The server can skip a stale/review-changed item; never count as published.
    failed += result['skipped'] as int? ?? 0;
    processed += chunk.length;
    onProgress(processed, approved.length);
  }
  return ReviewedBulkPublishResult(
    published: published,
    failed: failed,
    failedTitles: const [],
  );
}
