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
      body: Column(
        children: [
          Padding(
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
          Padding(
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
          SizedBox(
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
          Expanded(
            child: FutureBuilder<List<AdminContentItem>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingState(label: 'Loading content');
                }
                if (snapshot.hasError) {
                  return AppErrorState(
                    message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
                    onRetry: _reload,
                  );
                }
                final items = (snapshot.data ?? const <AdminContentItem>[])
                    .where((item) => _status == 'all' || item.status == _status)
                    .toList(growable: false);
                if (items.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.library_books_outlined,
                    title: 'No content found',
                    message: 'Create a resource or change the search filter.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _ContentCard(item: items[index]),
                  ),
                );
              },
            ),
          ),
        ],
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
