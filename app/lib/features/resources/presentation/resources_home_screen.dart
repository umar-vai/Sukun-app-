import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';

class ResourcesHomeScreen extends ConsumerStatefulWidget {
  const ResourcesHomeScreen({
    super.key,
    this.initialSectionSlug,
    this.embedded = false,
  });

  final String? initialSectionSlug;
  final bool embedded;

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
    final dedicatedPath = switch (section?.slug) {
      'quran' => '/resources/quran',
      'hadith' => '/resources/hadith',
      'dua-azkar' => '/resources/dua-azkar',
      'ruqyah' => '/resources/ruqyah',
      _ => null,
    };
    if (dedicatedPath != null) {
      context.push(dedicatedPath);
      return;
    }
    setState(() {
      _selectedSection = section;
      _resources = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverList.list(
              children: [
                SukunPageIntro(
                  eyebrow: 'Published library',
                  title: 'Islamic Resources',
                  subtitle: 'বিশ্বস্ত কুরআন, হাদিস, দোয়া, রুকইয়াহ ও শিক্ষামূলক রিসোর্স',
                  trailing: const SukunIconBadge(
                    icon: Icons.auto_stories_outlined,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 20),
                SukunSearchField(
                  controller: _searchController,
                  hintText: 'Search title, topic or reference',
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _refresh(),
                  onClear: () {
                    _searchController.clear();
                    _refresh();
                  },
                ),
                const SizedBox(height: 22),
                SukunSectionHeader(
                  title: 'Browse the library',
                  subtitle: 'Eight curated collections',
                  action: _selectedSection == null
                      ? null
                      : TextButton(
                          onPressed: () => _selectSection(null),
                          child: const Text('Show all'),
                        ),
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
                        childAspectRatio: columns == 4 ? 1.08 : 0.86,
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
                SukunSectionHeader(
                  title: _selectedSection?.title ?? 'Recently published',
                  subtitle: _selectedSection == null
                      ? 'Latest published additions'
                      : 'Published items in this section',
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          FutureBuilder<List<ContentResource>>(
            future: _resources,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160,
                    child: AppLoadingState(label: 'Loading resources'),
                  ),
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
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Islamic Resources')),
      body: content,
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
    return SukunSurface(
      tone: selected ? SukunSurfaceTone.soft : SukunSurfaceTone.white,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SukunIconBadge(icon: section.icon, size: 46),
          const SizedBox(height: 10),
          Text(
            section.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            section.titleBn,
            textAlign: TextAlign.center,
            style: SukunTypography.banglaBody(
              textStyle: Theme.of(context).textTheme.bodySmall,
            ).copyWith(color: SukunColors.muted),
          ),
        ],
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
    return SukunSurface(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SukunIconBadge(icon: _resourceIcon(resource.type)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.titleBn?.isNotEmpty == true
                      ? resource.titleBn!
                      : resource.title,
                  style: resource.titleBn?.isNotEmpty == true
                      ? SukunTypography.banglaDisplay(
                          textStyle: Theme.of(context).textTheme.titleMedium,
                        )
                      : Theme.of(context).textTheme.titleMedium,
                ),
                if (resource.titleBn?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    resource.title,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: SukunColors.muted),
                  ),
                ],
                if (resource.summary?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    resource.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 9),
                SukunStatusPill(
                  label: _typeLabel(resource.type),
                  tone: SukunStatusTone.brand,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: SukunColors.deepTide),
        ],
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
