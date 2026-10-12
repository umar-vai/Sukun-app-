import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/domain/book_audio_source_catalog.dart';
import 'package:sukun_life/features/content_admin/domain/private_resource_draft_batch.dart';
import 'package:url_launcher/url_launcher.dart';

/// Matches the actual owner-provided guide to third-party audio pages without
/// downloading, copying, auto-publishing or bypassing the existing Admin RPC.
class BookAudioSourceDialog extends ConsumerStatefulWidget {
  const BookAudioSourceDialog({super.key});

  @override
  ConsumerState<BookAudioSourceDialog> createState() =>
      _BookAudioSourceDialogState();
}

class _BookAudioSourceDialogState extends ConsumerState<BookAudioSourceDialog> {
  late final Future<List<BookAudioSourceCandidate>> _sources = _load();
  bool _saving = false;
  int _saved = 0;
  int _skipped = 0;
  int _failed = 0;

  bool get _allowed => PrivateResourceDraftBatch.mayImport(
    environment: AppEnvironment.name,
    supabaseUrl: AppEnvironment.supabaseUrl,
  );

  Future<List<BookAudioSourceCandidate>> _load() async {
    final json = await rootBundle.loadString(
      'assets/data/ruqyahbd_book_audio_crosswalk.json',
    );
    return parseBookAudioCatalog(json);
  }

  Future<void> _import(List<BookAudioSourceCandidate> entries) async {
    if (_saving || !_allowed) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(contentAdminRepositoryProvider);
      final existing = (await repo.listContent())
          .map((item) => item.slug)
          .toSet();
      final categories = await repo.listCategories();
      String? categoryId;
      for (final category in categories) {
        if (category.slug == 'ruqyah-audio') categoryId = category.id;
      }
      for (final candidate in entries) {
        if (existing.contains(candidate.slug)) {
          _skipped++;
        } else {
          try {
            final saved = await repo.saveContent(
              candidate.draftInput(categoryId: categoryId),
            );
            existing.add(saved.slug);
            _saved++;
          } catch (_) {
            _failed++;
          }
        }
        if (mounted) setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Staging Super Admin permission বা সংযোগ যাচাই করুন।',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('বইয়ে উল্লেখিত অডিও — Admin তালিকা'),
      content: SizedBox(
        width: 600,
        height: MediaQuery.sizeOf(context).height * .65,
        child: FutureBuilder<List<BookAudioSourceCandidate>>(
          future: _sources,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) {
                return const Text('অডিওর উৎস তালিকা পড়া যাচ্ছে না।');
              }
              return const Center(child: CircularProgressIndicator());
            }
            final tracks = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sukun Life Owner Authorization নথিভুক্ত রয়েছে। '
                  'এই তালিকা থেকে নতুন অডিও Staff-only Draft হিসেবে যোগ হবে; '
                  'প্রকাশনা ও বিষয়বস্তু পর্যালোচনা আলাদা থাকবে।',
                ),
                const SizedBox(height: 10),
                Text(
                  'নতুন Draft $_saved · আগেই আছে $_skipped · ব্যর্থ $_failed',
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: tracks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = tracks[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.titleBn),
                        subtitle: Text(
                          'বইয়ের paragraph: ${entry.bookParagraphIndices.join(', ')}'
                          '${entry.requiresContextReview ? ' · বিশেষ পর্যালোচনা' : ''}',
                        ),
                        trailing: IconButton(
                          tooltip: 'অফিসিয়াল উৎস খুলুন',
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () => launchUrl(
                            Uri.parse(entry.sourcePage),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                if (_allowed)
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _import(tracks),
                    icon: const Icon(Icons.library_add_outlined),
                    label: Text(
                      _saving
                          ? 'Staff-only Draft সংরক্ষণ চলছে…'
                          : 'সবগুলো Staff-only Draft হিসেবে আনুন',
                    ),
                  ),
                if (!_allowed)
                  const Text(
                    'শুধু নির্ধারিত staging project-এ Admin Draft import করা যাবে।',
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(_saved > 0),
          child: const Text('বন্ধ করুন'),
        ),
      ],
    );
  }
}
