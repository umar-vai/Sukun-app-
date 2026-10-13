import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/domain/selected_draft_actions.dart';
import 'package:uuid/uuid.dart';

/// Only actively reviewed editorial resources are eligible. Verified canonical
/// ayat/hadith require their separate verification workflow.
bool canManageSelectedReview(AdminContentItem item) {
  if (item.status != 'review' ||
      (item.visibility != 'staff_only' && item.visibility != 'public')) {
    return false;
  }
  if (RegExp(
    r'(^|[-_])(?:qa|test|fixture|sample|synthetic)(?:[-_]|$)',
    caseSensitive: false,
  ).hasMatch(item.slug)) {
    return false;
  }
  return !item.title.toLowerCase().contains('qa test');
}

List<AdminContentItem> selectedReviewCandidates(
  List<AdminContentItem> items,
) => List.unmodifiable(
  items.where(canManageSelectedReview).toList(growable: false),
);

class ManagedReviewResult {
  const ManagedReviewResult({
    required this.changed,
    required this.skipped,
    required this.failed,
  });

  final int changed;
  final int skipped;
  final int failed;
}

/// The backend locks current database state and uses the existing audit
/// lifecycle. "return_to_draft" does not change visibility or publish.
Future<ManagedReviewResult> manageSelectedReviews({
  required SupabaseClient client,
  required List<AdminContentItem> selected,
  required String action,
  required void Function(int processed, int total) onProgress,
}) async {
  if (action != 'return_to_draft' && action != 'archive') {
    throw ArgumentError.value(action, 'action');
  }
  final approved = selectedReviewCandidates(selected);
  if (approved.isEmpty) {
    return const ManagedReviewResult(changed: 0, skipped: 0, failed: 0);
  }
  var changed = 0;
  var skipped = 0;
  var failed = 0;
  var processed = 0;
  for (final chunk in splitDraftBatch(approved)) {
    final result = (await client.rpc(
      'manage_selected_content_reviews',
      params: {
        'p_content_item_ids': chunk.map((item) => item.id).toList(),
        'p_action': action,
        'p_request_id': const Uuid().v4(),
      },
    )) as Map<String, dynamic>;
    changed += result['changed'] as int? ?? 0;
    skipped += result['skipped'] as int? ?? 0;
    failed += result['failed'] as int? ?? 0;
    processed += chunk.length;
    onProgress(processed, approved.length);
  }
  return ManagedReviewResult(
    changed: changed,
    skipped: skipped,
    failed: failed,
  );
}
