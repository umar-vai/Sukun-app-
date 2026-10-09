import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_providers.dart';
import 'package:sukun_life/features/content_admin/data/content_admin_repository.dart';
import 'package:sukun_life/features/content_admin/domain/admin_content.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:uuid/uuid.dart';

class AdminContentListScreen extends ConsumerStatefulWidget {
  const AdminContentListScreen({super.key});

  @override
  ConsumerState<AdminContentListScreen> createState() =>
      _AdminContentListScreenState();
}

class _AdminContentListScreenState
    extends ConsumerState<AdminContentListScreen> {
  final _searchController = TextEditingController();
  late Future<List<AdminContentItem>> _items;
  String _status = 'all';
  String _type = 'all';

  @override
  void initState() {
    super.initState();
    _items = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<AdminContentItem>> _load() => ref
      .read(contentAdminRepositoryProvider)
      .listContent(query: _searchController.text);

  void _reload() {
    setState(() {
      _items = _load();
    });
  }

  Future<void> _create() async {
    final created = await context.push<AdminContentItem>('/admin/content/new');
    if (created != null && mounted) _reload();
  }

  Future<void> _installTaxonomy() async {
    try {
      final categories = await ref
          .read(contentAdminRepositoryProvider)
          .installStandardResourceTaxonomy(requestId: const Uuid().v4());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dua/Azkar and Ruqyah taxonomy is ready (${categories.length} categories).',
            ),
          ),
        );
      }
    } on ContentAdminException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Content CMS',
      selectedIndex: 2,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New resource'),
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          final refreshed = _load();
          setState(() => _items = refreshed);
          await refreshed;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                const SukunPageIntro(
                  eyebrow: 'Editorial workspace',
                  title: 'Content library',
                  subtitle: 'Add and review reusable resources through a simple guided workflow.',
                ),
                const SizedBox(height: 18),
                SukunSearchField(
                  controller: _searchController,
                  hintText: 'Search resources by title',
                  onSubmitted: (_) => _reload(),
                  onClear: () {
                    _searchController.clear();
                    _reload();
                  },
                ),
              ],
            ),
          ),
            ),
            SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _installTaxonomy,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Install approved taxonomy'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/admin/content/collections'),
                  icon: const Icon(Icons.collections_bookmark_outlined),
                  label: const Text('Ayat collections'),
                ),
              ],
            ),
          ),
            ),
            SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: FutureBuilder<List<AdminContentItem>>(
              future: _items,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <AdminContentItem>[];
                const types = <(String, String, IconData)>[
                  ('quran', 'Qur’an', Icons.auto_stories_outlined),
                  ('hadith', 'Hadith', Icons.menu_book_outlined),
                  ('dua', 'Dua & Azkar', Icons.volunteer_activism_outlined),
                  ('ruqyah', 'Ruqyah', Icons.health_and_safety_outlined),
                  ('audio', 'Audio', Icons.headphones_outlined),
                  ('video', 'Video', Icons.play_circle_outline),
                  ('book', 'Books & PDFs', Icons.picture_as_pdf_outlined),
                  ('article', 'Articles', Icons.article_outlined),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Browse by category',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 680 ? 4 : 2;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 10) /
                            columns;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final type in types)
                              SizedBox(
                                width: width,
                                child: Semantics(
                                  button: true,
                                  selected: _type == type.$1,
                                  child: SukunSurface(
                                    padding: const EdgeInsets.all(12),
                                    onTap: () => setState(
                                      () => _type = _type == type.$1
                                          ? 'all'
                                          : type.$1,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          type.$3,
                                          color: _type == type.$1
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                              : SukunColors.deepTide,
                                        ),
                                        const SizedBox(height: 7),
                                        Text(
                                          type.$2,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge,
                                        ),
                                        Text(
                                          '${items.where((item) => _matchesType(item.type, type.$1)).length} resources',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (_type != 'all')
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _type = 'all'),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Show all categories'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
            height: 52,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              scrollDirection: Axis.horizontal,
              children: [
                for (final status in const [
                  'all',
                  'draft',
                  'review',
                  'verified',
                  'published',
                  'archived',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SukunFilterPill(
                      selected: _status == status,
                      label: _display(status),
                      onTap: () => setState(() => _status = status),
                    ),
                  ),
              ],
            ),
          ),
            ),
            FutureBuilder<List<AdminContentItem>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: AppLoadingState(label: 'Loading content'),
                  );
                }
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: AppErrorState(
                      message: snapshot.error.toString(),
                      onRetry: _reload,
                    ),
                  );
                }
                final items = (snapshot.data ?? const <AdminContentItem>[])
                    .where(
                      (item) =>
                          (_status == 'all' || item.status == _status) &&
                          (_type == 'all' || _matchesType(item.type, _type)),
                    )
                    .toList(growable: false);
                if (items.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: AppEmptyState(
                      icon: Icons.library_books_outlined,
                      title: 'No content found',
                      message: 'Create a resource or change the search filter.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _ContentCard(item: items[index]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.item});

  final AdminContentItem item;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/admin/content/${item.id}/preview'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SukunIconBadge(icon: _typeIcon(item.type)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SukunStatusPill(label: _display(item.type)),
                    SukunStatusPill(
                      label: _display(item.status),
                      tone: item.status == 'published'
                          ? SukunStatusTone.success
                          : item.status == 'review'
                          ? SukunStatusTone.warning
                          : SukunStatusTone.neutral,
                    ),
                    SukunStatusPill(label: _display(item.visibility)),
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
}

bool _matchesType(String itemType, String selectedType) =>
    selectedType == 'book'
    ? const {'book', 'book_chapter', 'pdf'}.contains(itemType)
    : selectedType == 'dua'
    ? const {'dua', 'azkar', 'dua_azkar'}.contains(itemType)
    : selectedType == 'article'
    ? const {'article', 'guide'}.contains(itemType)
    : itemType == selectedType;

String _display(String value) => value
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

IconData _typeIcon(String type) => switch (type) {
  'quran' => Icons.auto_stories_outlined,
  'hadith' => Icons.menu_book_outlined,
  'audio' => Icons.headphones_outlined,
  'video' => Icons.play_circle_outline,
  'pdf' || 'book' || 'book_chapter' => Icons.picture_as_pdf_outlined,
  _ => Icons.article_outlined,
};
