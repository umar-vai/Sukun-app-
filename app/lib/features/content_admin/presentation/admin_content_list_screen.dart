import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/content_admin/domain/private_resource_draft_batch.dart';
import 'package:sukun_life/features/content_admin/presentation/private_resource_draft_import_dialog.dart';
import 'package:sukun_life/features/content_admin/presentation/book_audio_source_dialog.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/content_admin/domain/reviewed_bulk_publication.dart';
import 'package:sukun_life/features/content_admin/domain/selected_draft_actions.dart';
import 'package:sukun_life/features/content_admin/domain/selected_draft_review.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Final admin content workspace. Existing draft/review/publish RPCs and RLS
/// remain authoritative; this screen only simplifies navigation.
class AdminContentListScreen extends ConsumerStatefulWidget {
  const AdminContentListScreen({super.key});

  @override
  ConsumerState<AdminContentListScreen> createState() =>
      _AdminContentListScreenState();
}

class _AdminContentListScreenState
    extends ConsumerState<AdminContentListScreen> {
  final _searchController = TextEditingController();
  late Future<_ContentDashboardData> _data;
  AdminResourceKind? _selectedKind;
  bool _allDrafts = false;
  String _status = 'all';
  String _search = '';
  bool _publishingBatch = false;
  bool _archivingBatch = false;
  bool _submittingReviewBatch = false;
  final Set<String> _selectedDraftIds = <String>{};
  bool get _bulkBusy =>
      _publishingBatch || _archivingBatch || _submittingReviewBatch;
  int _batchProcessed = 0;
  int _batchTotal = 0;

  bool get _onDashboard => _selectedKind == null && !_allDrafts;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_ContentDashboardData> _load() async {
    final repo = ref.read(contentAdminRepositoryProvider);
    final results = await Future.wait([
      repo.listContent(),
      repo.listCategories(),
    ]);
    return _ContentDashboardData(
      items: results[0] as List<AdminContentItem>,
      categories: results[1] as List<ContentCategory>,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _data = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder shows the friendly retry state.
    }
  }

  void _openCategory(AdminResourceKind kind) {
    _searchController.clear();
    setState(() {
      _selectedKind = kind;
      _selectedDraftIds.clear();
      _allDrafts = false;
      _status = 'all';
      _search = '';
    });
  }

  void _openDrafts() {
    _searchController.clear();
    setState(() {
      _selectedKind = null;
      _selectedDraftIds.clear();
      _allDrafts = true;
      _status = 'draft';
      _search = '';
    });
  }

  void _openUnverifiedQuranDrafts() {
    const query = 'srg2024-qur-';
    _searchController.text = query;
    setState(() {
      // Source snippets are deliberately ARTICLE drafts until their exact
      // Surah/Ayah boundaries and canonical readings are verified.
      _selectedKind = AdminResourceKind.articleGuide;
      _selectedDraftIds.clear();
      _allDrafts = false;
      _status = 'draft';
      _search = query;
    });
  }

  void _backToCategories() {
    _searchController.clear();
    setState(() {
      _selectedKind = null;
      _selectedDraftIds.clear();
      _allDrafts = false;
      _status = 'all';
      _search = '';
    });
  }

  Future<void> _publishReviewedBatch(List<AdminContentItem> items) async {
    if (_bulkBusy) return;
    final candidates = reviewedBulkPublishCandidates(items);
    if (candidates.isEmpty) return;

    final confirmed = await showSukunDecisionDialog(
      context: context,
      title: '${candidates.length}টি যাচাইকৃত খসড়া প্রকাশ করবেন?',
      message:
          'শুধু অনুমোদিত উৎস ও প্রকাশের তথ্য থাকা উপকরণগুলো সবার জন্য '
          'দৃশ্যমান করা হবে। Draft → Review → Published ধাপে '
          'প্রতিটি পরিবর্তনের Admin audit history থাকবে। '
          'যেসব আয়াতে “সূত্র যাচাই প্রয়োজন” লেখা আছে এবং '
          'Private/QA খসড়া এই Batch থেকে বাদ থাকবে।',
      confirmLabel: 'প্রকাশ শুরু করুন',
      icon: Icons.publish_rounded,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _publishingBatch = true;
      _batchTotal = candidates.length;
      _batchProcessed = 0;
    });
    try {
      final result = await publishReviewedResourceBatch(
        client: Supabase.instance.client,
        candidates: candidates,
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
              _batchProcessed = processed;
              _batchTotal = total;
            });
          }
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          content: Text(
            '${result.published}টি প্রকাশিত, '
            '${result.failed}টি ব্যর্থ/যাচাই প্রয়োজন। '
            'ব্যর্থ হলে Draft/Review অবস্থা থেকে পুনরায় চেষ্টা করুন।',
          ),
        ),
      );
      setState(() => _selectedDraftIds.clear());
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'প্রকাশ করা যায়নি. Super Admin লগইন ও Server Update '
            'যাচাই করুন; খসড়াগুলো পুনরায় লোড করে চেষ্টা করুন।',
          ),
        ),
      );
      await _refresh();
    } finally {
      if (mounted) {
        setState(() => _publishingBatch = false);
      }
    }
  }

  Future<void> _archiveSelectedDrafts(List<AdminContentItem> selected) async {
    if (_bulkBusy || selected.isEmpty) return;
    final confirmed = await showSukunDecisionDialog(
      context: context,
      title: '${selected.length}টি খসড়া আর্কাইভ করবেন?',
      message:
          'এটি স্থায়ীভাবে ডিলিট করবে না। নির্বাচিত খসড়াগুলো '
          'খসড়া তালিকা থেকে সরিয়ে সংরক্ষিত (Archive) ট্যাবে রাখবে। '
          'অন্য অ্যাডমিন ইতিমধ্যে প্রকাশ করে থাকলে সেই রেকর্ড বাদ যাবে।',
      confirmLabel: 'আর্কাইভ করুন',
      icon: Icons.archive_outlined,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _archivingBatch = true;
      _batchTotal = selected.length;
      _batchProcessed = 0;
    });
    try {
      final result = await archiveSelectedDrafts(
        client: Supabase.instance.client,
        ids: selected.map((item) => item.id).toList(growable: false),
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
              _batchProcessed = processed;
              _batchTotal = total;
            });
          }
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          content: Text(
            '${result.archived}টি আর্কাইভ হয়েছে, '
            '${result.skipped}টি অবস্থা বদলে যাওয়ায় বাদ, '
            '${result.failed}টি ব্যর্থ।',
          ),
        ),
      );
      setState(() => _selectedDraftIds.clear());
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'আর্কাইভ সম্পন্ন হয়নি। তালিকা রিফ্রেশ করে বাকি খসড়া '
            'আবার নির্বাচন করুন।',
          ),
        ),
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _archivingBatch = false);
    }
  }

  Future<void> _submitSelectedDraftsForReview(
    List<AdminContentItem> items,
  ) async {
    if (_bulkBusy) return;
    final candidates = bulkReviewCandidates(items);
    if (candidates.isEmpty) return;

    final confirmed = await showSukunDecisionDialog(
      context: context,
      title: '${candidates.length}টি খসড়া যাচাইয়ের জন্য পাঠাবেন?',
      message:
          'শুধুমাত্র নির্বাচিত খসড়াগুলো Draft থেকে Review তালিকায় যাবে। '
          'এতে কোনো উপকরণ প্রকাশিত বা কুরআনের আয়াত যাচাইকৃত বলে গণ্য হবে না। '
          'Private/QA খসড়া বাদ থাকবে এবং প্রতিটি পরিবর্তনে Admin audit থাকবে।',
      confirmLabel: 'যাচাইয়ের জন্য পাঠান',
      icon: Icons.fact_check_outlined,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _submittingReviewBatch = true;
      _batchTotal = candidates.length;
      _batchProcessed = 0;
    });
    try {
      final result = await submitSelectedDraftsForReview(
        client: Supabase.instance.client,
        selected: candidates,
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
              _batchProcessed = processed;
              _batchTotal = total;
            });
          }
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          content: Text(
            '${result.submitted}টি যাচাইয়ের তালিকায় পাঠানো হয়েছে, '
            '${result.skipped}টি বাদ, ${result.failed}টি ব্যর্থ।',
          ),
        ),
      );
      setState(() => _selectedDraftIds.clear());
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'যাচাইয়ের জন্য পাঠানো সম্পন্ন হয়নি। '
            'তালিকা রিফ্রেশ করে বাকি খসড়া আবার নির্বাচন করুন।',
          ),
        ),
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _submittingReviewBatch = false);
    }
  }

  Widget _draftSelectionToolbar(List<AdminContentItem> visibleItems) {
    final selected = visibleItems
        .where((item) => _selectedDraftIds.contains(item.id))
        .toList(growable: false);
    final publishable = reviewedBulkPublishCandidates(selected);
    final reviewable = bulkReviewCandidates(selected);
    final allVisibleSelected =
        visibleItems.isNotEmpty &&
        visibleItems.every((item) => _selectedDraftIds.contains(item.id));

    return SukunSurface(
      tone: SukunSurfaceTone.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${selected.length}টি নির্বাচিত · ${visibleItems.length}টি দৃশ্যমান',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              TextButton.icon(
                onPressed: _bulkBusy || visibleItems.isEmpty
                    ? null
                    : () {
                        setState(() {
                          if (allVisibleSelected) {
                            _selectedDraftIds.removeAll(
                              visibleItems.map((item) => item.id),
                            );
                          } else {
                            _selectedDraftIds.addAll(
                              visibleItems.map((item) => item.id),
                            );
                          }
                        });
                      },
                icon: Icon(
                  allVisibleSelected
                      ? Icons.deselect_outlined
                      : Icons.select_all_rounded,
                ),
                label: Text(
                  allVisibleSelected ? 'নির্বাচন সরান' : 'সব নির্বাচন',
                ),
              ),
              if (selected.isNotEmpty)
                TextButton(
                  onPressed: _bulkBusy
                      ? null
                      : () => setState(() => _selectedDraftIds.clear()),
                  child: const Text('সব বাতিল'),
                ),
            ],
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _bulkBusy || publishable.isEmpty
                      ? null
                      : () => _publishReviewedBatch(selected),
                  icon: const Icon(Icons.publish_outlined),
                  label: Text('প্রকাশ করুন (${publishable.length})'),
                ),
                OutlinedButton.icon(
                  onPressed: _bulkBusy || reviewable.isEmpty
                      ? null
                      : () => _submitSelectedDraftsForReview(selected),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text('যাচাইয়ের জন্য পাঠান (${reviewable.length})'),
                ),
                OutlinedButton.icon(
                  onPressed: _bulkBusy
                      ? null
                      : () => _archiveSelectedDrafts(selected),
                  icon: const Icon(Icons.archive_outlined),
                  label: Text('ডিলিট / আর্কাইভ (${selected.length})'),
                ),
              ],
            ),
            if (reviewable.length < selected.length) ...[
              const SizedBox(height: 8),
              Text(
                '${selected.length - reviewable.length}টি Private/QA খসড়া '
                'এই Review ব্যাচ থেকে বাদ থাকবে।',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (publishable.length < selected.length) ...[
              const SizedBox(height: 8),
              Text(
                '${selected.length - publishable.length}টি খসড়ার '
                'উৎস/অনুমোদন যাচাই বাকি; এগুলো Bulk Publish হবে না।',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
          if (_bulkBusy) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _batchTotal == 0 ? null : _batchProcessed / _batchTotal,
            ),
            Text('প্রক্রিয়াধীন: $_batchProcessed / $_batchTotal'),
          ],
          const SizedBox(height: 6),
          Text(
            'ডিলিট মানে নিরাপদ আর্কাইভ। প্রতিটি পরিবর্তনে '
            'Super Admin অনুমোদন ও অডিট হিস্ট্রি সংরক্ষিত হবে।',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _openAudioReferences() async {
    final imported = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const BookAudioSourceDialog(),
    );
    if (mounted && imported == true) await _refresh();
  }

  Future<void> _importPrivateCatalog() async {
    if (!PrivateResourceDraftBatch.mayImport(
      environment: AppEnvironment.name,
      supabaseUrl: AppEnvironment.supabaseUrl,
    )) {
      return;
    }
    final imported = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PrivateResourceDraftImportDialog(),
    );
    if (mounted && imported == true) await _refresh();
  }

  Future<void> _create() async {
    final created = await context.push<AdminContentItem>(
      '/admin/content/new',
      extra: _selectedKind,
    );
    if (mounted && created != null) await _refresh();
  }

  Future<void> _openItem(AdminContentItem item) async {
    await context.push('/admin/content/${item.id}/preview');
    if (mounted) await _refresh();
  }

  Future<void> _installTaxonomy() async {
    try {
      await ref
          .read(contentAdminRepositoryProvider)
          .installStandardResourceTaxonomy(requestId: const Uuid().v4());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('অনুমোদিত উপকরণের বিভাগগুলো প্রস্তুত হয়েছে।'),
        ),
      );
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('বিভাগগুলো প্রস্তুত করা যায়নি। আবার চেষ্টা করুন।'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'উপকরণ ব্যবস্থাপনা',
      selectedIndex: 2,
      body: FutureBuilder<_ContentDashboardData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                // Switching category or status must always show the heading
                // and primary Add action, not reuse the old list's scroll.
                key: ValueKey(
                  '${_onDashboard
                      ? 'dashboard'
                      : _allDrafts
                      ? 'drafts'
                      : _selectedKind!.name}-$_status',
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                children: [
                  if (_onDashboard)
                    ..._dashboard(context, data, snapshot)
                  else
                    ..._categoryContent(context, data, snapshot),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _dashboard(
    BuildContext context,
    _ContentDashboardData? data,
    AsyncSnapshot<_ContentDashboardData> snapshot,
  ) {
    final items = data?.items ?? const <AdminContentItem>[];
    final categories = data?.categories ?? const <ContentCategory>[];
    final drafts = items.where((item) => item.status == 'draft').length;
    final quranPending = items
        .where(
          (item) =>
              item.status == 'draft' && item.slug.startsWith('srg2024-qur-'),
        )
        .length;
    final review = items
        .where((item) => item.status == 'review' || item.status == 'verified')
        .length;

    return [
      const SukunPageIntro(
        eyebrow: 'সহজে কাজ শুরু করুন',
        title: 'উপকরণ ব্যবস্থাপনা',
        subtitle: 'যে ধরনের উপকরণ যোগ বা সংশোধন করতে চান, সেই বিভাগ খুলুন।',
      ),
      const SizedBox(height: 16),
      _DashboardShortcut(
        icon: Icons.edit_note_rounded,
        title: 'সংরক্ষিত খসড়া',
        detail: data == null
            ? 'অসম্পূর্ণ উপকরণগুলো দেখুন'
            : '$draftsটি খসড়া · পরে আবার কাজ করতে পারবেন',
        onTap: _openDrafts,
      ),
      const SizedBox(height: 10),
      _DashboardShortcut(
        icon: Icons.fact_check_outlined,
        title: 'যাচাইয়ের অপেক্ষায়',
        detail: data == null
            ? 'যাচাই বা প্রকাশের অপেক্ষায় থাকা উপকরণ'
            : '$reviewটি উপকরণ যাচাই অথবা প্রকাশের অপেক্ষায়',
        onTap: () {
          _openDrafts();
          setState(() => _status = 'review');
        },
      ),
      const SizedBox(height: 24),
      Text('বিভাগ বেছে নিন', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(
        'প্রতিটি বিভাগে প্রকাশিত উপকরণ, খসড়া ও নতুন উপকরণ যোগ করার ব্যবস্থা আছে।',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 310 ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final kind in AdminResourceKind.values)
                SizedBox(
                  width: width,
                  child: _KindCard(
                    kind: kind,
                    count: data == null
                        ? null
                        : items
                              .where(
                                (item) => _kindFor(item, categories) == kind,
                              )
                              .length,
                    onTap: () => _openCategory(kind),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 18),
      _DashboardShortcut(
        icon: Icons.menu_book_outlined,
        title: 'কুরআনের পাঠ — উৎস যাচাই বাকি',
        detail: data == null
            ? 'মূল বইয়ের আয়াত ও পাঠের অংশ যাচাই করুন'
            : '$quranPendingটি বইয়ের পাঠের খসড়া · সূরা–আয়াত যাচাই না হওয়া পর্যন্ত অপ্রকাশিত',
        onTap: _openUnverifiedQuranDrafts,
      ),
      const SizedBox(height: 10),
      if (snapshot.hasError)
        const SukunSurface(
          tone: SukunSurfaceTone.soft,
          child: Text(
            'সংরক্ষিত উপকরণের সংখ্যা এখন আনা যাচ্ছে না। বিভাগ খুলে পরে আবার চেষ্টা করুন।',
          ),
        ),
      if (snapshot.connectionState == ConnectionState.waiting)
        const Padding(
          padding: EdgeInsets.all(14),
          child: Center(child: CircularProgressIndicator()),
        ),
      const SizedBox(height: 12),
      if (PrivateResourceDraftBatch.mayImport(
        environment: AppEnvironment.name,
        supabaseUrl: AppEnvironment.supabaseUrl,
      )) ...[
        OutlinedButton.icon(
          onPressed: _importPrivateCatalog,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Private Dua/Amal Draft Catalog Import (Staging)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openAudioReferences,
          icon: const Icon(Icons.headphones_outlined),
          label: const Text('বইয়ে উল্লেখিত Ruqyah BD অডিও — ১৯টি উৎস'),
        ),
        const SizedBox(height: 12),
      ],
      OutlinedButton.icon(
        onPressed: () => context.push('/admin/content/collections'),
        icon: const Icon(Icons.collections_bookmark_outlined),
        label: const Text('আয়াতের সংগ্রহ পরিচালনা'),
      ),
      ExpansionTile(
        title: const Text('উন্নত সেটিংস'),
        tilePadding: EdgeInsets.zero,
        children: [
          ListTile(
            title: const Text('অনুমোদিত উপকরণের বিভাগ প্রস্তুত করুন'),
            subtitle: const Text('সাধারণভাবে এটি একবারই প্রয়োজন হয়।'),
            onTap: _installTaxonomy,
          ),
        ],
      ),
    ];
  }

  List<Widget> _categoryContent(
    BuildContext context,
    _ContentDashboardData? data,
    AsyncSnapshot<_ContentDashboardData> snapshot,
  ) {
    final title = _allDrafts
        ? (_status == 'review' ? 'যাচাইয়ের অপেক্ষায়' : 'সব বিভাগের খসড়া')
        : _kindLabel(_selectedKind!);
    final categories = data?.categories ?? const <ContentCategory>[];
    final items = (data?.items ?? const <AdminContentItem>[])
        .where((item) {
          if (!_allDrafts && _kindFor(item, categories) != _selectedKind) {
            return false;
          }
          if (_status == 'review') {
            if (item.status != 'review' && item.status != 'verified') {
              return false;
            }
          } else if (_status != 'all' && item.status != _status) {
            return false;
          }
          final query = _search.trim().toLowerCase();
          return query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              (item.titleBn?.toLowerCase().contains(query) ?? false) ||
              item.slug.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _backToCategories,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('সব বিভাগে ফিরে যান'),
        ),
      ),
      const SizedBox(height: 6),
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text(
        _allDrafts
            ? 'এখান থেকে অসম্পূর্ণ উপকরণ আবার খুলে সম্পাদনা করুন।'
            : 'এই বিভাগের উপকরণ দেখুন, নতুন যোগ করুন অথবা আগের কাজ শেষ করুন।',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      if (!_allDrafts)
        FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add_rounded),
          label: Text('নতুন ${_kindLabel(_selectedKind!)} যোগ করুন'),
        ),
      const SizedBox(height: 14),
      SukunSearchField(
        controller: _searchController,
        hintText: 'নাম বা বিষয় লিখে খুঁজুন',
        onChanged: (value) => setState(() {
          _search = value;
          _selectedDraftIds.clear();
        }),
        onSubmitted: (value) => setState(() => _search = value),
        onClear: () {
          _searchController.clear();
          setState(() {
            _search = '';
            _selectedDraftIds.clear();
          });
        },
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 53,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final tab in const <(String, String)>[
              ('all', 'সব'),
              ('published', 'প্রকাশিত'),
              ('draft', 'খসড়া'),
              ('review', 'যাচাই'),
              ('archived', 'সংরক্ষিত'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SukunFilterPill(
                  selected: _status == tab.$1,
                  label: tab.$2,
                  onTap: () => setState(() {
                    _status = tab.$1;
                    _selectedDraftIds.clear();
                  }),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (_status == 'draft' && snapshot.hasData) _draftSelectionToolbar(items),
      const SizedBox(height: 10),
      if (snapshot.connectionState == ConnectionState.waiting)
        const AppLoadingState(label: 'উপকরণগুলো আনা হচ্ছে…')
      else if (snapshot.hasError)
        AppErrorState(
          message: 'উপকরণগুলো আনা যায়নি। আবার চেষ্টা করুন।',
          onRetry: _refresh,
        )
      else if (items.isEmpty)
        const AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'এখানে এখনো কোনো উপকরণ নেই',
          message: 'অন্য ট্যাবে দেখুন অথবা নতুন উপকরণ যোগ করুন।',
        )
      else
        for (final item in items) ...[
          _ContentCard(
            item: item,
            onTap: () => _openItem(item),
            selected: _selectedDraftIds.contains(item.id),
            onSelected: _status == 'draft' && !_bulkBusy
                ? (checked) => setState(() {
                    if (checked) {
                      _selectedDraftIds.add(item.id);
                    } else {
                      _selectedDraftIds.remove(item.id);
                    }
                  })
                : null,
          ),
          const SizedBox(height: 10),
        ],
      const SizedBox(height: 40),
    ];
  }
}

class _ContentDashboardData {
  const _ContentDashboardData({required this.items, required this.categories});

  final List<AdminContentItem> items;
  final List<ContentCategory> categories;
}

AdminResourceKind _kindFor(
  AdminContentItem item,
  List<ContentCategory> categories,
) {
  ContentCategory? category;
  for (final candidate in categories) {
    if (candidate.id == item.categoryId) {
      category = candidate;
      break;
    }
  }
  return resourceKindForItem(item, category: category);
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.kind,
    required this.count,
    required this.onTap,
  });

  final AdminResourceKind kind;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SukunSurface(
    radius: 20,
    padding: const EdgeInsets.all(14),
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SukunIconBadge(icon: _kindIcon(kind), size: 42),
        const SizedBox(height: 12),
        Text(_kindLabel(kind), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          count == null ? 'উপকরণ খুলুন' : '$countটি উপকরণ',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: SukunColors.muted),
        ),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerRight,
          child: Icon(
            Icons.arrow_forward_rounded,
            color: SukunColors.deepTide,
            size: 20,
          ),
        ),
      ],
    ),
  );
}

class _DashboardShortcut extends StatelessWidget {
  const _DashboardShortcut({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SukunSurface(
    padding: const EdgeInsets.all(14),
    onTap: onTap,
    child: Row(
      children: [
        SukunIconBadge(icon: icon, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.item,
    required this.onTap,
    this.selected = false,
    this.onSelected,
  });

  final AdminContentItem item;
  final VoidCallback onTap;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) => SukunSurface(
    padding: const EdgeInsets.all(14),
    onTap: onTap,
    child: Row(
      children: [
        if (onSelected != null) ...[
          Checkbox(
            key: ValueKey('draft-select-${item.id}'),
            value: selected,
            onChanged: (value) => onSelected!(value ?? false),
            semanticLabel: '${item.titleBn ?? item.title} নির্বাচন',
          ),
          const SizedBox(width: 4),
        ],
        SukunIconBadge(icon: _typeIcon(item.type), size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.titleBn?.trim().isNotEmpty == true
                    ? item.titleBn!
                    : item.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  SukunStatusPill(label: _statusLabel(item.status)),
                  SukunStatusPill(
                    label: item.visibility == 'public'
                        ? 'সবার জন্য'
                        : 'নির্ধারিত রোগীর জন্য',
                  ),
                ],
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: SukunColors.deepTide),
      ],
    ),
  );
}

String _statusLabel(String value) => switch (value) {
  'draft' => 'খসড়া',
  'review' => 'যাচাই বাকি',
  'verified' => 'অনুমোদিত',
  'published' => 'প্রকাশিত',
  'archived' => 'সংরক্ষিত',
  _ => 'বিবেচনাধীন',
};

String _kindLabel(AdminResourceKind kind) => switch (kind) {
  AdminResourceKind.quranAyah => 'কুরআনের আয়াত',
  AdminResourceKind.hadith => 'হাদিস',
  AdminResourceKind.quranAudio => 'কুরআন অডিও',
  AdminResourceKind.ruqyahAudio => 'রুকইয়াহ অডিও',
  AdminResourceKind.bookPdf => 'বই ও পিডিএফ',
  AdminResourceKind.video => 'ভিডিও',
  AdminResourceKind.duaAzkar => 'দোয়া ও যিকর',
  AdminResourceKind.articleGuide => 'লেখা ও নির্দেশিকা',
};

IconData _kindIcon(AdminResourceKind kind) => switch (kind) {
  AdminResourceKind.quranAyah => Icons.auto_stories_outlined,
  AdminResourceKind.hadith => Icons.menu_book_outlined,
  AdminResourceKind.quranAudio => Icons.graphic_eq_rounded,
  AdminResourceKind.ruqyahAudio => Icons.headphones_outlined,
  AdminResourceKind.bookPdf => Icons.picture_as_pdf_outlined,
  AdminResourceKind.video => Icons.play_circle_outline_rounded,
  AdminResourceKind.duaAzkar => Icons.volunteer_activism_outlined,
  AdminResourceKind.articleGuide => Icons.article_outlined,
};

IconData _typeIcon(String type) => switch (type) {
  'quran' => Icons.auto_stories_outlined,
  'hadith' => Icons.menu_book_outlined,
  'audio' => Icons.headphones_outlined,
  'video' => Icons.play_circle_outline,
  'pdf' || 'book' || 'book_chapter' => Icons.picture_as_pdf_outlined,
  _ => Icons.article_outlined,
};
