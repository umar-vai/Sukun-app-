import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  Future<void> _transition(String transition, {AdminContentItem? item}) async {
    if ((transition == 'submit' ||
            transition == 'verify' ||
            transition == 'publish') &&
        item != null) {
      final validation = item.publicationValidationError();
      if (validation != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validation),
            action: SnackBarAction(label: 'সংশোধন করুন', onPressed: _edit),
          ),
        );
        return;
      }
    }
    final confirmed = await showSukunDecisionDialog(
      context: context,
      title: '${_transitionLabel(transition)}?',
      message: _transitionExplanation(transition),
      confirmLabel: _transitionLabel(transition),
      icon: _transitionIcon(transition),
    );
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    try {
      await ref
          .read(contentAdminRepositoryProvider)
          .transitionContent(
            contentItemId: widget.contentItemId,
            transition: transition,
            requestId: const Uuid().v4(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('উপকরণটি ${_pastTense(transition)}।')),
      );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('উপকরণটির পরিবর্তন করা যায়নি। আবার চেষ্টা করুন।'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('উপকরণ যাচাই')),
      body: FutureBuilder<_PreviewData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'উপকরণ আনা হচ্ছে…');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          final item = data.item;
          if (item == null) {
            return const AppEmptyState(
              icon: Icons.search_off,
              title: 'উপকরণটি পাওয়া যায়নি',
              message: 'এটি এখন আর পাওয়া যাচ্ছে না।',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
            children: [
              SukunPageIntro(
                eyebrow: 'উপকরণ যাচাই',
                title: item.title,
                subtitle:
                    'প্রকাশের আগে উপকরণটি যাচাই করুন ও প্রয়োজনীয় অনুমোদন দিন।',
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
                  _StatusChip(label: _statusLabel(item)),
                  _StatusChip(label: _audienceLabel(item.visibility)),
                  if (item.isCanonical)
                    _StatusChip(
                      label: _verificationLabel(item.verificationStatus),
                    ),
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
                  title: 'আরবি',
                  body: item.arabicText!,
                  rtl: true,
                  textStyle: SukunTypography.canonicalReligiousText(
                    textStyle: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(height: 1.9),
                  ),
                ),
              if (item.banglaText != null)
                _PreviewSection(
                  title: 'বাংলা',
                  body: item.banglaText!,
                  textStyle: SukunTypography.banglaBody(
                    textStyle: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(height: 1.65),
                  ),
                ),
              if (item.transliteration != null)
                _PreviewSection(title: 'উচ্চারণ', body: item.transliteration!),
              if (item.translation != null)
                _PreviewSection(title: 'অনুবাদ', body: item.translation!),
              if (item.body != null)
                _PreviewSection(title: 'বিস্তারিত লেখা', body: item.body!),
              const SizedBox(height: 26),
              const SukunSectionHeader(
                title: 'উৎস ও তথ্যসূত্র',
                subtitle: 'উপকরণটির উৎস যাচাইয়ের জন্য প্রয়োজনীয় তথ্য।',
              ),
              const SizedBox(height: 8),
              _Metadata(item: item),
              const SizedBox(height: 24),
              const SukunSectionHeader(
                title: 'যাচাই ও প্রকাশ',
                subtitle: 'প্রকাশ ও পরিবর্তনের সব তথ্য নিরাপদে সংরক্ষিত হয়।',
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
                      label: const Text('সংশোধন করুন'),
                    ),
                  if (item.status == 'draft')
                    FilledButton.icon(
                      onPressed: _working
                          ? null
                          : () => _transition('submit', item: item),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('যাচাইয়ের জন্য পাঠান'),
                    ),
                  if (item.isCanonical &&
                      item.status == 'review' &&
                      item.verificationStatus != 'অনুমোদিত হয়েছে')
                    FilledButton.icon(
                      onPressed: _working
                          ? null
                          : () => _transition('verify', item: item),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('উৎস অনুমোদন করুন'),
                    ),
                  if (item.isCanonical &&
                      item.status == 'review' &&
                      item.verificationStatus != 'অনুমোদিত হয়েছে')
                    OutlinedButton.icon(
                      onPressed: _working ? null : () => _transition('reject'),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('সংশোধনের জন্য ফেরত দিন'),
                    ),
                  if ((!item.isCanonical && item.status == 'review') ||
                      (item.isCanonical && item.status == 'অনুমোদিত হয়েছে'))
                    FilledButton.icon(
                      onPressed: _working
                          ? null
                          : () => _transition('publish', item: item),
                      icon: const Icon(Icons.publish_outlined),
                      label: const Text('প্রকাশ করুন'),
                    ),
                  if (item.status == 'প্রকাশিত হয়েছে')
                    OutlinedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _transition('unpublish'),
                      icon: const Icon(Icons.visibility_off_outlined),
                      label: const Text('প্রকাশ বন্ধ করুন'),
                    ),
                  if (item.status != 'সংরক্ষিত হয়েছে')
                    TextButton.icon(
                      onPressed: _working ? null : () => _transition('archive'),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('সংরক্ষণাগারে রাখুন'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const SukunSectionHeader(
                title: 'পরিবর্তনের ইতিহাস',
                subtitle: 'অ্যাডমিনের অনুমোদন ও প্রকাশের রেকর্ড।',
              ),
              const SizedBox(height: 8),
              if (data.reviews.isEmpty)
                const SukunSurface(
                  tone: SukunSurfaceTone.soft,
                  showBorder: false,
                  child: Text('এখনো কোনো পরিবর্তনের রেকর্ড নেই।'),
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
                            review.notes ?? 'কোনো মন্তব্য নেই',
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
    tone: label == 'প্রকাশিত' || label == 'উৎস অনুমোদিত'
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
      ('Reference', item.referenceText),
      ('Approved source', item.sourceReference),
      ('Edition or version', item.sourceEdition),
      ('Online source', item.sourceUrl),
      ('Bangla translation source', item.translationSource),
      ('Surah', _surah(item)),
      ('Ayah', _ayah(item)),
      ('Kitab / collection', item.collectionName),
      ('Hadith number', item.hadithNumber),
      ('Grade', item.grade),
      ('Author', item.author),
      ('Publisher', item.publisher),
      ('Source / rights acknowledgement', item.rightsNote),
      ('External link', _externalLink(item)),
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
  'submit' => 'উপকরণটি যাচাইয়ের জন্য পাঠান। কুরআন ও হাদিসের উৎস অনুমোদিত না হলে প্রকাশ করা যাবে না।',
  'verify' => 'আসল লেখা ও উৎস অনুমোদিত তথ্যসূত্রের সঙ্গে মিলিয়ে নিশ্চিত করুন।',
  'reject' => 'লেখা বা ইতিহাস না মুছে সংশোধনের জন্য ফেরত দিন।',
  'publish' => 'যাচাই করা উপকরণটি নির্ধারিত পাঠকদের জন্য প্রকাশ করুন।',
  'unpublish' => 'আগের তথ্য রেখে উপকরণটি পাঠকদের তালিকা থেকে সরান।',
  'archive' =>
    'উপকরণটি ইতিহাসসহ সংরক্ষণাগারে রাখুন। রোগীরা এটি দেখতে পাবেন না।',
  _ => 'পরিবর্তনটি নিশ্চিত করুন।',
};

String _transitionLabel(String transition) => switch (transition) {
  'submit' => 'যাচাইয়ের জন্য পাঠান',
  'verify' => 'উৎস অনুমোদন করুন',
  'reject' => 'সংশোধনের জন্য ফেরত দিন',
  'publish' => 'প্রকাশ করুন',
  'unpublish' => 'প্রকাশ বন্ধ করুন',
  'archive' => 'সংরক্ষণাগারে রাখুন',
  _ => _label(transition),
};

String _statusLabel(AdminContentItem item) => switch (item.status) {
  'draft' => 'খসড়া',
  'review' => item.isCanonical ? 'উৎস যাচাই বাকি' : 'প্রকাশের অপেক্ষায়',
  'অনুমোদিত হয়েছে' => 'উৎস অনুমোদিত',
  'প্রকাশিত হয়েছে' => 'প্রকাশিত',
  'সংরক্ষিত হয়েছে' => 'সংরক্ষিত',
  _ => _label(item.status),
};

String _verificationLabel(String value) => switch (value) {
  'pending' => 'উৎস যাচাই বাকি',
  'অনুমোদিত হয়েছে' => 'উৎস অনুমোদিত',
  'সংশোধনের জন্য ফেরত গেছে' => 'সংশোধন প্রয়োজন',
  _ => 'উৎস যাচাই শুরু হয়নি',
};

String _audienceLabel(String value) => switch (value) {
  'public' => 'সবাই',
  'patient_only' => 'লগইন করা রোগীরা',
  'assigned_only' => 'নির্ধারিত রোগীরা',
  'staff_only' => 'শুধু কর্মীরা',
  _ => _label(value),
};

String? _externalLink(AdminContentItem item) {
  if (item.mediaSourceType == 'youtube' && item.youtubeVideoId != null) {
    return 'https://www.youtube.com/watch?v=${item.youtubeVideoId}';
  }
  return item.mediaUrl;
}

String _pastTense(String transition) => switch (transition) {
  'submit' => 'যাচাইয়ের জন্য পাঠানো হয়েছে',
  'verify' => 'অনুমোদিত হয়েছে',
  'reject' => 'সংশোধনের জন্য ফেরত গেছে',
  'publish' => 'প্রকাশিত হয়েছে',
  'unpublish' => 'প্রকাশ বন্ধ হয়েছে',
  'archive' => 'সংরক্ষিত হয়েছে',
  _ => 'পরিবর্তিত হয়েছে',
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
