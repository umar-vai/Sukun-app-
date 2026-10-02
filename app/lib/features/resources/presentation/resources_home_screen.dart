import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';

class ResourcesHomeScreen extends ConsumerStatefulWidget {
  const ResourcesHomeScreen({super.key, this.initialSectionSlug});

  final String? initialSectionSlug;

  @override
  ConsumerState<ResourcesHomeScreen> createState() =>
      _ResourcesHomeScreenState();
}

class _ResourcesHomeScreenState extends ConsumerState<ResourcesHomeScreen> {
  final _searchController = TextEditingController();
  ResourceSection? _selectedSection;
  late Future<List<ContentResource>> _resources;

  @override
  void initState() {
    super.initState();
    _selectedSection = resourceSectionBySlug(widget.initialSectionSlug);
    _resources = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ContentResource>> _load() {
    return ref
        .read(resourcesRepositoryProvider)
        .browseResources(
          query: _searchController.text,
          types: _selectedSection?.types ?? const {},
          categoryPrefixes: _selectedSection?.categoryPrefixes ?? const {},
        );
  }

  void _refresh() {
    setState(() {
      _resources = _load();
    });
  }

  void _selectSection(ResourceSection? section) {
    setState(() {
      _selectedSection = section;
      _resources = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Islamic Resources')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              sliver: SliverList.list(
                children: [
                  Text(
                    'ইসলামিক রিসোর্স',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Browse verified and published Qur’an, Hadith, Dua, Ruqyah, books, guides, audio and video.',
                  ),
                  const SizedBox(height: 18),
                  SearchBar(
                    controller: _searchController,
                    hintText: 'Search title, topic or reference',
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _refresh();
                          },
                          icon: const Icon(Icons.close),
                          tooltip: 'Clear search',
                        ),
                    ],
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _refresh(),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Browse sections',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (_selectedSection != null)
                        TextButton(
                          onPressed: () => _selectSection(null),
                          child: const Text('Show all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 720 ? 4 : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: columns == 4 ? 1.2 : 1.05,
                        ),
                        itemCount: resourceSections.length,
                        itemBuilder: (context, index) {
                          final section = resourceSections[index];
                          return _SectionCard(
                            section: section,
                            selected: section.slug == _selectedSection?.slug,
                            onTap: () => _selectSection(section),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _selectedSection?.title ?? 'Recently published',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            FutureBuilder<List<ContentResource>>(
              future: _resources,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppLoadingState(label: 'Loading resources'),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppErrorState(
                      message: snapshot.error.toString(),
                      onRetry: _refresh,
                    ),
                  );
                }
                final resources = snapshot.data!;
                if (resources.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      title: 'No published resources found',
                      message: _selectedSection == null
                          ? 'Try another search. Only resources you are permitted to read appear here.'
                          : 'No permitted resources are published in this section yet.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList.separated(
                    itemCount: resources.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ResourceCard(
                      resource: resources[index],
                      onTap: () =>
                          context.push('/resources/${resources[index].id}'),
                    ),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final ResourceSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? SukunColors.mist : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(section.icon, size: 30, color: SukunColors.deepTide),
              const SizedBox(height: 8),
              Text(
                section.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(section.titleBn, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource, required this.onTap});

  final ContentResource resource;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: SukunColors.mist,
          foregroundColor: SukunColors.deepTide,
          child: Icon(_resourceIcon(resource.type)),
        ),
        title: Text(
          resource.titleBn?.isNotEmpty == true
              ? resource.titleBn!
              : resource.title,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resource.titleBn?.isNotEmpty == true) Text(resource.title),
            if (resource.summary?.isNotEmpty == true)
              Text(
                resource.summary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 6),
            Text(_typeLabel(resource.type)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

IconData _resourceIcon(String type) => switch (type) {
  'quran' => Icons.auto_stories_outlined,
  'hadith' => Icons.format_quote_outlined,
  'dua' || 'amal' => Icons.favorite_outline,
  'audio' => Icons.headphones_outlined,
  'video' => Icons.ondemand_video_outlined,
  'pdf' || 'book' || 'book_chapter' => Icons.picture_as_pdf_outlined,
  _ => Icons.article_outlined,
};

String _typeLabel(String type) => type
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
