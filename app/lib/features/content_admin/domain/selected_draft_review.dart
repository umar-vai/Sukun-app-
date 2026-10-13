import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/domain/selected_draft_actions.dart';
import 'package:uuid/uuid.dart';

/// A review request must not grant publication or canonical verification.
/// Unverified scripture can enter the human review queue; protected patient
/// records and QA fixtures must never enter a bulk editorial workflow.
bool canBulkSubmitDraftForReview(AdminContentItem item) {
  if (item.status != 'draft' || item.visibility == 'patient_only') {
    return false;
  }
  if (RegExp(
    r'(^|[-_])(?:qa|test|fixture|sample|synthetic)(?:[-_]|$)',
    caseSensitive: false,
  ).hasMatch(item.slug)) {
    return false;
  }
  if (item.title.toLowerCase().contains('qa test')) return false;
  return true;
}

List<AdminContentItem> bulkReviewCandidates(
  List<AdminContentItem> items,
) => List.unmodifiable(
  items.where(canBulkSubmitDraftForReview).toList(growable: false),
);

class BulkReviewResult {
  const BulkReviewResult({
    required this.submitted,
    required this.skipped,
    required this.failed,
  });

  final int submitted;
  final int skipped;
  final int failed;
}

/// Each call is bounded and is executed with the current authenticated
/// Super Admin session. The database locks rows and invokes the existing
/// audited 'submit' transition, never changing visibility to public.
Future<BulkReviewResult> submitSelectedDraftsForReview({
  required SupabaseClient client,
  required List<AdminContentItem> selected,
  required void Function(int processed, int total) onProgress,
}) async {
  final approved = bulkReviewCandidates(selected);
  if (approved.isEmpty) {
    return const BulkReviewResult(submitted: 0, skipped: 0, failed: 0);
  }

  var processed = 0;
  var submitted = 0;
  var skipped = 0;
  var failed = 0;
  for (final chunk in splitDraftBatch(approved)) {
    final response = await client.rpc(
      'submit_selected_content_drafts_for_review',
      params: {
        'p_content_item_ids': chunk.map((item) => item.id).toList(),
        'p_request_id': const Uuid().v4(),
      },
    );
    final result = response as Map<String, dynamic>;
    submitted += result['submitted'] as int? ?? 0;
    skipped += result['skipped'] as int? ?? 0;
    failed += result['failed'] as int? ?? 0;
    processed += chunk.length;
    onProgress(processed, approved.length);
  }
  return BulkReviewResult(
    submitted: submitted,
    skipped: skipped,
    failed: failed,
  );
}
