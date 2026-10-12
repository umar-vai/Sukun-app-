import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/config/app_environment.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/domain/private_resource_draft_batch.dart';

/// Authenticated Admin-only operation, with backend RPC authorization.
/// No automatic publishing, patient linking, or unattended remote ingestion.
class PrivateResourceDraftImportDialog extends ConsumerStatefulWidget {
  const PrivateResourceDraftImportDialog({super.key});

  @override
  ConsumerState<PrivateResourceDraftImportDialog> createState() =>
      _PrivateResourceDraftImportDialogState();
}

class _PrivateResourceDraftImportDialogState
    extends ConsumerState<PrivateResourceDraftImportDialog> {
  PrivateResourceDraftBatch? _batch;
  String? _error;
  int _saved = 0;
  int _skipped = 0;
  int _failed = 0;
  int _processed = 0;
  bool _busy = false;
  bool _stopRequested = false;
  bool _complete = false;

  bool get _allowed => PrivateResourceDraftBatch.mayImport(
    environment: AppEnvironment.name,
    supabaseUrl: AppEnvironment.supabaseUrl,
  );

  Future<void> _choose() async {
    if (_busy || !_allowed) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
        allowMultiple: false,
      );
      if (!mounted || result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        throw const FormatException('Please select a local JSON file.');
      }
      final batch = PrivateResourceDraftBatch.parse(bytes);
      setState(() {
        _batch = batch;
        _error = null;
        _complete = false;
        _saved = 0;
        _skipped = 0;
        _failed = 0;
        _processed = 0;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _batch = null;
          _error = 'যাচাইকৃত private draft JSON নির্বাচন করুন।';
        });
      }
    }
  }

  Future<void> _import() async {
    final batch = _batch;
    if (!_allowed || batch == null || _busy || _complete) return;
    setState(() {
      _busy = true;
      _stopRequested = false;
      _error = null;
    });
    try {
      final repository = ref.read(contentAdminRepositoryProvider);
      // Existing items are never overwritten. Resumable after interruption.
      final existing = (await repository.listContent())
          .map((item) => item.slug)
          .toSet();
      for (final entry in batch.items) {
        if (_stopRequested || !_allowed) break;
        if (existing.contains(entry.input.slug)) {
          _skipped++;
        } else {
          try {
            await repository.saveContent(entry.input);
            existing.add(entry.input.slug);
            _saved++;
          } catch (_) {
            _failed++;
          }
        }
        _processed++;
        if (mounted) setState(() {});
      }
      if (mounted) {
        setState(() {
          _complete = !_stopRequested && _processed == batch.items.length;
          if (_failed != 0) {
            _error = 'কিছু খসড়া সংরক্ষণ হয়নি। পরে আবার Import করলে আগেরগুলো বাদ যাবে।';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Admin permission বা staging connection যাচাই করুন। কোনো কনটেন্ট প্রকাশ হয়নি।';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = _batch;
    return AlertDialog(
      title: const Text('Private Resource Draft Import'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sukun Life Staging-এ original guide-এর খসড়া সংরক্ষণ করুন। '
                'সব উপকরণ Staff-only ও Draft থাকবে। প্রকাশ বা Patient Assignment '
                'আলাদাভাবে Admin যাচাইয়ের পরে হবে।',
              ),
              const SizedBox(height: 12),
              if (!_allowed)
                const Text(
                  'Production বা অনির্ধারিত backend-এ bulk import নিষিদ্ধ।',
                  style: TextStyle(color: Colors.red),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _allowed && !_busy ? _choose : null,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Private Draft JSON নির্বাচন করুন'),
              ),
              if (batch != null) ...[
                const SizedBox(height: 16),
                Text(
                  '${batch.items.length}টি private draft যাচাই হয়েছে',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'ধর্মীয় উৎস যাচাই বাকি: '
                  '${batch.items.where((e) => e.needsCanonicalReview).length} · '
                  'অতিরিক্ত নির্দেশনা যাচাই: '
                  '${batch.items.where((e) => e.needsClinicalReview).length}',
                ),
                const SizedBox(height: 12),
                for (final entry in batch.items.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${entry.sourceId} · ${entry.input.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (batch.items.length > 6)
                  Text('… আরও ${batch.items.length - 6}টি খসড়া'),
                const SizedBox(height: 12),
                if (_busy || _processed > 0) ...[
                  LinearProgressIndicator(
                    value: _processed / batch.items.length,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'সংরক্ষিত $_saved · আগেই আছে $_skipped · '
                    'ব্যর্থ $_failed · পরীক্ষিত $_processed/${batch.items.length}',
                  ),
                ],
                if (_complete)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Import শেষ। সব উপকরণ Staff-only Draft। প্রকাশের আগে যাচাই করুন।',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_busy)
          TextButton(
            onPressed: () => setState(() => _stopRequested = true),
            child: const Text('বাকি Import বন্ধ করুন'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(_saved > 0),
          child: Text(_saved > 0 ? 'শেষ করুন' : 'বন্ধ করুন'),
        ),
        if (batch != null && !_complete)
          FilledButton(
            onPressed: _busy || !_allowed ? null : _import,
            child: Text(_busy ? 'সংরক্ষণ হচ্ছে…' : 'Staff-only Draft সংরক্ষণ'),
          ),
      ],
    );
  }
}
