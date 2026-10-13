import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// A draft can be selected even when its source is not yet publishable.
/// Bulk archive is a soft delete, not permanent removal of the CMS row.
class DraftArchiveResult {
  const DraftArchiveResult({
    required this.archived,
    required this.skipped,
    required this.failed,
  });

  final int archived;
  final int skipped;
  final int failed;
}

List<List<T>> splitDraftBatch<T>(List<T> items, {int batchSize = 80}) {
  if (batchSize < 1 || batchSize > 100) {
    throw ArgumentError.value(batchSize, 'batchSize');
  }
  return [
    for (var i = 0; i < items.length; i += batchSize)
      items.sublist(i, (i + batchSize).clamp(0, items.length)),
  ];
}

/// Calls a server-side, actor-authenticated and audited archive transition.
/// Each RPC rechecks status under a database row lock, and refuses records
/// concurrently published by another Super Admin.
Future<DraftArchiveResult> archiveSelectedDrafts({
  required SupabaseClient client,
  required List<String> ids,
  required void Function(int processed, int total) onProgress,
}) async {
  final uniqueIds = ids.toSet().toList(growable: false);
  var processed = 0;
  var archived = 0;
  var skipped = 0;
  var failed = 0;
  for (final chunk in splitDraftBatch(uniqueIds)) {
    final raw = await client.rpc(
      'archive_selected_content_drafts',
      params: {
        'p_content_item_ids': chunk,
        'p_request_id': const Uuid().v4(),
      },
    );
    final result = raw as Map<String, dynamic>;
    archived += result['archived'] as int? ?? 0;
    skipped += result['skipped'] as int? ?? 0;
    failed += result['failed'] as int? ?? 0;
    processed += chunk.length;
    onProgress(processed, uniqueIds.length);
  }
  return DraftArchiveResult(
    archived: archived,
    skipped: skipped,
    failed: failed,
  );
}
