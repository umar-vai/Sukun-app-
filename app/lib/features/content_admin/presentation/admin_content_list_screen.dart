import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:uuid/uuid.dart';

/// Admin resource workspace: pick a type, add or tap to edit. Saving in the
/// editor publishes immediately; there is no draft or review queue.
class AdminContentListScreen extends ConsumerStatefulWidget {
  const AdminContentListScreen({super.key});

  @override
  ConsumerState<AdminContentListScreen> createState() =>
      _AdminContentListScreenState();
}

enum _ItemAction { publish, unpublish, archive }

class _AdminContentListScreenState
    extends ConsumerState<AdminContentListScreen> {
  final _searchController = TextEditingController();
  late Future<_ContentDashboardData> _data;
  AdminResourceKind? _selectedKind;
  String _status = 'all';
  String _search = '';
  String? _busyItemId;

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
    setState(() => _data = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder shows the friendly retry state.
    }
  }

  void _openCategory(AdminResourceKind? kind) {
    _searchController.clear();
    setState(() {
      _selectedKind = kind;
      _status = 'all';
      _search = '';
    });
  }

  Future<void> _create() async {
    var kind = _selectedKind;
    if (kind == AdminResourceKind.bookPdf) {
      kind = await showModalBottomSheet<AdminResourceKind>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('বই / পিডিএফ'),
                onTap: () => Navigator.pop(sheet, AdminResourceKind.bookPdf),
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('আর্টিকেল'),
                onTap: () =>
                    Navigator.pop(sheet, AdminResourceKind.articleGuide),
              ),
            ],
          ),
        ),
      );
      if (!mounted || kind == null) return;
    }
    final created = await context.push<AdminContentItem>(
      '/admin/content/new',
      extra: kind,
    );
    if (mounted && created != null) await _refresh();
  }

  Future<void> _edit(AdminContentItem item) async {
    final updated = await context.push<AdminContentItem>(
      '/admin/content/${item.id}/edit',
    );
    if (mounted && updated != null) await _refresh();
  }

  Future<void> _runAction(AdminContentItem item, _ItemAction action) async {
    if (_busyItemId != null) return;
    if (action == _ItemAction.archive) {
      final confirmed = await showSukunDecisionDialog(
        context: context,
        title: 'উপকরণটি আর্কাইভ করবেন?',
        message: 'এটি অ্যাপ থেকে সরে যাবে। পরে আবার প্রকাশ করা যাবে।',
        confirmLabel: 'আর্কাইভ করুন',
        cancelLabel: 'বাতিল',
        icon: Icons.archive_outlined,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _busyItemId = item.id);
    try {
      await ref
          .read(contentAdminRepositoryProvider)
          .transitionContent(
            contentItemId: item.id,
            transition: action.name,
            requestId: const Uuid().v4(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (action) {
            _ItemAction.publish => 'উপকরণটি প্রকাশিত হয়েছে।',
            _ItemAction.unpublish => 'উপকরণটি লুকানো হয়েছে।',
            _ItemAction.archive => 'উপকরণটি আর্কাইভ হয়েছে।',
          }),
        ),
      );
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('কাজটি করা যায়নি। আবার চেষ্টা করুন।')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'উপকরণ ব্যবস্থাপনা',
      selectedIndex: -1,
      body: FutureBuilder<_ContentDashboardData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              // Switching category or filter must show the heading and the
              // Add action, not reuse the old list's scroll position.
              key: ValueKey('${_selectedKind?.name ?? 'dashboard'}-$_status'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                if (_selectedKind == null)
                  ..._dashboard(context, data, snapshot)
                else
                  ..._categoryContent(context, data, snapshot),
              ],
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
    return [
      const SukunPageIntro(
        eyebrow: 'উপকরণ',
        title: 'উপকরণ ব্যবস্থাপনা',
        subtitle: 'ধরন বেছে নিন। নতুন যোগ করুন বা কোনোটিতে চাপ দিয়ে বদলান।',
      ),
      const SizedBox(height: 18),
      if (snapshot.hasError)
        AppErrorState(
          message: 'উপকরণগুলো আনা যায়নি। আবার চেষ্টা করুন।',
          onRetry: _refresh,
        )
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 310 ? 2 : 1;
            final width =
                (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final kind in AdminResourceKind.values)
                  if (kind != AdminResourceKind.articleGuide)
                    SizedBox(
                      width: width,
                      child: _KindCard(
                        kind: kind,
                        count: data == null
                            ? null
                            : items
                                  .where(
                                    (item) => _matchesKind(
                                      _kindFor(item, categories),
                                      kind,
                                    ),
                                  )
                                  .length,
                        onTap: () => _openCategory(kind),
                      ),
                    ),
              ],
            );
          },
        ),
    ];
  }

  List<Widget> _categoryContent(
    BuildContext context,
    _ContentDashboardData? data,
    AsyncSnapshot<_ContentDashboardData> snapshot,
  ) {
    final kind = _selectedKind!;
    final categories = data?.categories ?? const <ContentCategory>[];
    final query = _search.trim().toLowerCase();
    final items = (data?.items ?? const <AdminContentItem>[])
        .where((item) {
          if (!_matchesKind(_kindFor(item, categories), kind)) return false;
          final group = _statusGroup(item.status);
          if (_status != 'all' && group != _status) return false;
          return query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              (item.titleBn?.toLowerCase().contains(query) ?? false);
        })
        .toList(growable: false);

    return [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _openCategory(null),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('সব ধরন'),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: Text(
              _kindLabel(kind),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          FilledButton.icon(
            key: const Key('content-list-add'),
            onPressed: _create,
            icon: const Icon(Icons.add_rounded),
            label: const Text('যোগ করুন'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      SukunSearchField(
        controller: _searchController,
        hintText: 'নাম লিখে খুঁজুন',
        onChanged: (value) => setState(() => _search = value),
        onSubmitted: (value) => setState(() => _search = value),
        onClear: () {
          _searchController.clear();
          setState(() => _search = '');
        },
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 53,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final tab in const <(String, String)>[
              ('all', 'সব'),
              ('published', 'প্রকাশিত'),
              ('hidden', 'লুকানো'),
              ('archived', 'আর্কাইভ'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SukunFilterPill(
                  selected: _status == tab.$1,
                  label: tab.$2,
                  onTap: () => setState(() => _status = tab.$1),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (snapshot.connectionState == ConnectionState.waiting)
        const AppLoadingState(label: 'উপকরণগুলো আনা হচ্ছে…')
      else if (snapshot.hasError)
        AppErrorState(
          message: 'উপকরণগুলো আনা যায়নি। আবার চেষ্টা করুন।',
          onRetry: _refresh,
        )
      else if (items.isEmpty)
        const AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'এখানে কোনো উপকরণ নেই',
          message: 'উপরের "যোগ করুন" চেপে নতুন উপকরণ দিন।',
        )
      else
        for (final item in items) ...[
          _ContentCard(
            item: item,
            busy: _busyItemId == item.id,
            onTap: item.status == 'archived' ? null : () => _edit(item),
            onAction: _busyItemId == null
                ? (action) => _runAction(item, action)
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

/// Articles are listed together with books, as they always have been.
bool _matchesKind(AdminResourceKind itemKind, AdminResourceKind selected) =>
    itemKind == selected ||
    (selected == AdminResourceKind.bookPdf &&
        itemKind == AdminResourceKind.articleGuide);

/// Legacy draft/review/verified rows are simply "hidden" (not live).
String _statusGroup(String status) => switch (status) {
  'published' => 'published',
  'archived' => 'archived',
  _ => 'hidden',
};

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
    child: Row(
      children: [
        SukunIconBadge(icon: _kindIcon(kind), size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _kindLabel(kind),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                count == null ? ' ' : '$countটি',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: SukunColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.item,
    required this.onTap,
    required this.onAction,
    this.busy = false,
  });

  final AdminContentItem item;
  final VoidCallback? onTap;
  final ValueChanged<_ItemAction>? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final group = _statusGroup(item.status);
    return SukunSurface(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      onTap: onTap,
      child: Row(
        children: [
          SukunIconBadge(icon: _typeIcon(item.type), size: 40),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (group != 'published') ...[
                  const SizedBox(height: 6),
                  SukunStatusPill(
                    label: group == 'archived' ? 'আর্কাইভ' : 'লুকানো',
                    tone: SukunStatusTone.neutral,
                  ),
                ],
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<_ItemAction>(
              key: ValueKey('content-actions-${item.id}'),
              enabled: onAction != null,
              tooltip: 'আরও',
              onSelected: onAction,
              itemBuilder: (context) => [
                if (group != 'published')
                  const PopupMenuItem(
                    value: _ItemAction.publish,
                    child: Text('প্রকাশ করুন'),
                  ),
                if (group == 'published')
                  const PopupMenuItem(
                    value: _ItemAction.unpublish,
                    child: Text('লুকিয়ে রাখুন'),
                  ),
                if (group != 'archived')
                  const PopupMenuItem(
                    value: _ItemAction.archive,
                    child: Text('আর্কাইভ করুন'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

String _kindLabel(AdminResourceKind kind) => switch (kind) {
  AdminResourceKind.quranAyah => 'কুরআনের আয়াত',
  AdminResourceKind.hadith => 'হাদিস',
  AdminResourceKind.quranAudio => 'কুরআন অডিও',
  AdminResourceKind.ruqyahAudio => 'রুকইয়াহ অডিও',
  AdminResourceKind.bookPdf => 'বই ও আর্টিকেল',
  AdminResourceKind.video => 'ভিডিও',
  AdminResourceKind.duaAzkar => 'দোয়া ও যিকর',
  AdminResourceKind.articleGuide => 'আর্টিকেল',
  AdminResourceKind.blog => 'ব্লগ',
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
  AdminResourceKind.blog => Icons.edit_note_outlined,
};

IconData _typeIcon(String type) => switch (type) {
  'quran' => Icons.auto_stories_outlined,
  'hadith' => Icons.menu_book_outlined,
  'audio' => Icons.headphones_outlined,
  'video' => Icons.play_circle_outline,
  'pdf' || 'book' || 'book_chapter' => Icons.picture_as_pdf_outlined,
  _ => Icons.article_outlined,
};
