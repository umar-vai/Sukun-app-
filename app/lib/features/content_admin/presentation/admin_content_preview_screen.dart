import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:uuid/uuid.dart';

class AdminContentPreviewScreen extends ConsumerStatefulWidget {
  const AdminContentPreviewScreen({super.key, required this.contentItemId});

  final String contentItemId;

  @override
  ConsumerState<AdminContentPreviewScreen> createState() =>
      _AdminContentPreviewScreenState();
}

class _AdminContentPreviewScreenState
    extends ConsumerState<AdminContentPreviewScreen> {
  late Future<_PreviewData> _data;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_PreviewData> _load() async {
    final repository = ref.read(contentAdminRepositoryProvider);
    final results = await Future.wait([
      repository.getContent(widget.contentItemId),
      repository.listReviews(widget.contentItemId),
    ]);
    return _PreviewData(
      item: results[0] as AdminContentItem?,
      reviews: results[1] as List<ContentReview>,
    );
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _edit() async {
    final updated = await context.push<AdminContentItem>(
      '/admin/content/${widget.contentItemId}/edit',
    );
    if (updated != null && mounted) _reload();
  }

  Future<void> _transition(String transition) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SukunIconBadge(icon: _transitionIcon(transition), size: 54),
                const SizedBox(height: 16),
                Text(
                  '${_label(transition)} resource?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _transitionExplanation(transition),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: SukunColors.muted),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Reviewer note (optional)',
                    helperText: 'Admin-only; never shown to patients.',
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(_label(transition)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final notes = notesController.text;
    notesController.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await ref
          .read(contentAdminRepositoryProvider)
          .transitionContent(
            contentItemId: widget.contentItemId,
            transition: transition,
            notes: notes,
            requestId: const Uuid().v4(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resource ${_pastTense(transition)}.')),
      );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resource preview')),
      body: FutureBuilder<_PreviewData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Loading preview');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          final item = data.item;
          if (item == null) {
            return const AppEmptyState(
              icon: Icons.search_off,
              title: 'Resource not found',
              message: 'It may no longer be available.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
            children: [
              SukunPageIntro(
                eyebrow: 'Editorial review',
                title: item.title,
                subtitle: 'Preview the patient-facing content and verify every source detail before publishing.',
                trailing: SukunIconBadge(
                  icon: item.isCanonical
                      ? Icons.verified_outlined
                      : Icons.visibility_outlined,
                  size: 54,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(label: _label(item.type)),
                  _StatusChip(label: _label(item.status)),
                  _StatusChip(label: _label(item.visibility)),
                  if (item.isCanonical)
                    _StatusChip(label: _label(item.verificationStatus)),
                ],
              ),
              if (item.titleBn != null) ...[
                const SizedBox(height: 18),
                Text(
                  item.titleBn!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
              if (item.summary != null) ...[
                const SizedBox(height: 16),
                Text(
                  item.summary!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if (item.arabicText != null)
                _PreviewSection(
                  title: 'Arabic',
                  body: item.arabicText!,
                  rtl: true,
                  textStyle: SukunTypography.canonicalReligiousText(
                    textStyle: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(height: 1.9),
                  ),
                ),
              if (item.banglaText != null)
                _PreviewSection(
                  title: 'Bangla',
                  body: item.banglaText!,
                  textStyle: SukunTypography.banglaBody(
                    textStyle: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(height: 1.65),
                  ),
                ),
              if (item.transliteration != null)
                _PreviewSection(
                  title: 'Transliteration',
                  body: item.transliteration!,
                ),
              if (item.translation != null)
                _PreviewSection(title: 'Translation', body: item.translation!),
              if (item.body != null)
                _PreviewSection(title: 'Content', body: item.body!),
              const SizedBox(height: 26),
              const SukunSectionHeader(
                title: 'Structured metadata',
                subtitle: 'Source, ownership, visibility, and canonical reference details.',
              ),
              const SizedBox(height: 8),
              _Metadata(item: item),
              const SizedBox(height: 24),
              const SukunSectionHeader(
                title: 'Editorial workflow',
                subtitle:
                    'Each state transition is audited and preserves history.',
              ),
              const SizedBox(height: 10),
              if (_working) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (item.canEdit)
                    OutlinedButton.icon(
                      onPressed: _working ? null : _edit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  if (item.status == 'draft')
                    FilledButton.icon(
                      onPressed: _working ? null : () => _transition('submit'),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Submit for review'),
                    ),
                  if (item.isCanonical &&
                      item.status == 'review' &&
                      item.verificationStatus != 'rejected') ...[
                    FilledButton.icon(
                      onPressed: _working ? null : () => _transition('verify'),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Verify source'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _working ? null : () => _transition('reject'),
                      icon: const Icon(Icons.report_outlined),
                      label: const Text('Reject verification'),
                    ),
                  ],
                  if ((!item.isCanonical && item.status == 'review') ||
                      (item.isCanonical && item.status == 'verified'))
                    FilledButton.icon(
                      onPressed: _working ? null : () => _transition('publish'),
                      icon: const Icon(Icons.publish_outlined),
                      label: const Text('Publish'),
                    ),
                  if (item.status == 'published')
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _transition('unpublish'),
                      icon: const Icon(Icons.visibility_off_outlined),
                      label: const Text('Unpublish'),
                    ),
                  if (item.status != 'archived')
                    TextButton.icon(
                      onPressed: _working ? null : () => _transition('archive'),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archive'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const SukunSectionHeader(
                title: 'Review history',
                subtitle: 'Admin-only notes and workflow events.',
              ),
              const SizedBox(height: 8),
              if (data.reviews.isEmpty)
                const SukunSurface(
                  tone: SukunSurfaceTone.soft,
                  showBorder: false,
                  child: Text('No workflow events yet.'),
                )
              else
                SukunSurface(
                  child: Column(
                    children: [
                      for (final review in data.reviews)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const SukunIconBadge(
                            icon: Icons.history_rounded,
                            size: 40,
                          ),
                          title: Text(_label(review.decision)),
                          subtitle: Text(
                            review.notes ?? 'No reviewer note',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SukunStatusPill(
    label: label,
    tone: label == 'Published' || label == 'Verified'
        ? SukunStatusTone.success
        : SukunStatusTone.brand,
  );
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.title,
    required this.body,
    this.rtl = false,
    this.textStyle,
  });

  final String title;
  final String body;
  final bool rtl;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: SukunSurface(
      tone: rtl ? SukunSurfaceTone.soft : SukunSurfaceTone.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: SelectableText(body, style: textStyle),
          ),
        ],
      ),
    ),
  );
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.item});

  final AdminContentItem item;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String?)>[
      ('Slug', item.slug),
      ('Reference', item.referenceText),
      ('Source type', item.sourceType),
      ('Source reference', item.sourceReference),
      ('Source edition', item.sourceEdition),
      ('Source URL', item.sourceUrl),
      ('Translation source', item.translationSource),
      ('Surah', _surah(item)),
      ('Ayah', _ayah(item)),
      ('Hadith collection', item.collectionName),
      ('Hadith book', item.bookName),
      ('Hadith number', item.hadithNumber),
      ('Grade', item.grade),
      ('Author', item.author),
      ('Publisher', item.publisher),
      ('Rights', item.rightsNote),
      ('Media type', item.mediaSourceType),
      ('Media URL', item.mediaUrl),
      ('YouTube video ID', item.youtubeVideoId),
    ].where((row) => row.$2 != null && row.$2!.trim().isNotEmpty);
    return SukunSurface(
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 132,
                    child: Text(
                      row.$1,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Expanded(child: SelectableText(row.$2!)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewData {
  const _PreviewData({required this.item, required this.reviews});

  final AdminContentItem? item;
  final List<ContentReview> reviews;
}

String? _surah(AdminContentItem item) {
  if (item.surahNumber == null) return null;
  return '${item.surahNumber}${item.surahName == null ? '' : ' — ${item.surahName}'}';
}

String? _ayah(AdminContentItem item) {
  if (item.ayahNumber == null) return null;
  return item.ayahEndNumber == null
      ? '${item.ayahNumber}'
      : '${item.ayahNumber}–${item.ayahEndNumber}';
}

String _label(String value) => value
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

String _transitionExplanation(String transition) => switch (transition) {
  'submit' => 'Move this draft into the review queue.',
  'verify' => 'Confirm that the canonical text and all source metadata were checked against an approved source.',
  'reject' => 'Reject this verification. The item remains editable and cannot be published.',
  'publish' => 'Make this resource available according to its visibility rule.',
  'unpublish' => 'Remove this resource from public and patient browsing while preserving it for review.',
  'archive' => 'Preserve this resource and its history as archived. It will not be editable or visible to patients.',
  _ => 'Apply this workflow change.',
};

String _pastTense(String transition) => switch (transition) {
  'submit' => 'submitted for review',
  'verify' => 'verified',
  'reject' => 'rejected',
  'publish' => 'published',
  'unpublish' => 'unpublished',
  'archive' => 'archived',
  _ => 'updated',
};

IconData _transitionIcon(String transition) => switch (transition) {
  'submit' => Icons.rate_review_outlined,
  'verify' => Icons.verified_outlined,
  'reject' => Icons.report_outlined,
  'publish' => Icons.publish_outlined,
  'unpublish' => Icons.visibility_off_outlined,
  'archive' => Icons.archive_outlined,
  _ => Icons.sync_rounded,
};
