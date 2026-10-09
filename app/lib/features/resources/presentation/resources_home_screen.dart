import 'dart:async';

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
import 'package:sukun_life/features/resources/presentation/youtube_player_screen.dart';
import 'package:sukun_life/features/resources/domain/video_navigation.dart';

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
  late Future<List<ContentResource>> _resources;
  Timer? _searchDebounce;
  bool _searchPending = false;

  @override
  void initState() {
    super.initState();
    _resources = _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ContentResource>> _load() {
    final query = _searchController.text.trim();
    // The hub is category navigation only; never load the entire catalog.
    // Matching items appear only after the user actively searches.
    if (query.isEmpty) return Future.value(const <ContentResource>[]);
    return ref.read(resourcesRepositoryProvider).browseResources(query: query);
  }

  Future<void> _refresh() async {
    _searchDebounce?.cancel();
    final future = _load();
    setState(() {
      _searchPending = false;
      _resources = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder already presents the friendly retry state.
    }
  }

  void _scheduleSearch(String _) {
    _searchDebounce?.cancel();
    if (_searchController.text.trim().isEmpty) {
      _refresh();
      return;
    }
    // Do not show results from the previous query while the user is typing.
    setState(() => _searchPending = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _refresh();
    });
  }

  void _selectSection(ResourceSection section) {
    _searchDebounce?.cancel();
    context.push('/resources/${section.slug}');
  }

  void _openSearchResult(ContentResource resource) {
    if (opensYoutubePlayerDirectly(resource)) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SukunYoutubePlayerScreen(
            resource: resource.linkedResource,
            autoPlay: true,
          ),
        ),
      );
      return;
    }
    context.push(
      widget.embedded
          ? '/patient/resources/${resource.id}'
          : '/resources/${resource.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = _searchController.text.trim().isNotEmpty;
    final content = RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverList.list(
              children: [
                SukunPageIntro(
                  eyebrow: 'বিশ্বস্ত উপকরণের সংগ্রহ',
                  title: 'ইসলামিক পাঠ ও অডিও',
                  subtitle: 'বিশ্বস্ত কুরআন, হাদিস, দোয়া, রুকইয়াহ ও শিক্ষামূলক রিসোর্স',
                  trailing: const SukunIconBadge(
                    icon: Icons.auto_stories_outlined,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 20),
                SukunSearchField(
                  controller: _searchController,
                  hintText: 'নাম বা বিষয় লিখে খুঁজুন',
                  onChanged: _scheduleSearch,
                  onSubmitted: (_) => _refresh(),
                  onClear: () {
                    _searchController.clear();
                    _refresh();
                  },
                ),
                const SizedBox(height: 22),
                SukunSectionHeader(
                  title: 'বিষয় অনুযায়ী দেখুন',
                  subtitle: 'আপনার পছন্দের বিভাগ বেছে নিন',
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
                        mainAxisExtent: columns == 4 ? 118 : 124,
                      ),
                      itemCount: resourceSections.length,
                      itemBuilder: (context, index) {
                        final section = resourceSections[index];
                        return _SectionCard(
                          section: section,
                          onTap: () => _selectSection(section),
                        );
                      },
                    );
                  },
                ),
                if (hasSearch) ...[
                  const SizedBox(height: 24),
                  const SukunSectionHeader(
                    title: 'অনুসন্ধানের ফলাফল',
                    subtitle: 'আপনার অনুসন্ধানে পাওয়া উপকরণ',
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          if (hasSearch && _searchPending)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: AppLoadingState(label: 'অনুসন্ধান করা হচ্ছে…'),
              ),
            )
          else if (hasSearch)
            FutureBuilder<List<ContentResource>>(
              future: _resources,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 160,
                      child: AppLoadingState(label: 'উপকরণ আনা হচ্ছে…'),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppErrorState(
                      message: 'উপকরণ আনা যাচ্ছে না। আবার চেষ্টা করুন।',
                      onRetry: _refresh,
                    ),
                  );
                }
                final resources = snapshot.data!;
                if (resources.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      title: 'কোনো উপকরণ পাওয়া যায়নি',
                      message: _searchController.text.trim().isNotEmpty
                          ? 'অন্য শব্দ দিয়ে আবার খুঁজুন।'
                          : 'এখানে এখনো কোনো উপকরণ দেওয়া হয়নি।',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList.separated(
                    itemCount: resources.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) => ResourceCard(
                      resource: resources[index],
                      onTap: () => _openSearchResult(resources[index]),
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
      appBar: AppBar(title: const Text('ইসলামিক পাঠ ও অডিও')),
      body: content,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.onTap});

  final ResourceSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      tone: SukunSurfaceTone.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SukunIconBadge(icon: section.icon, size: 40),
          const SizedBox(height: 8),
          Text(
            section.titleBn,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SukunTypography.banglaBody(
              textStyle: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class ResourceCard extends StatelessWidget {
  const ResourceCard({super.key, required this.resource, required this.onTap});

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

String _typeLabel(String type) => switch (type) {
  'quran' => 'কুরআন',
  'hadith' => 'হাদিস',
  'dua' => 'দোয়া',
  'amal' => 'আমল',
  'audio' => 'অডিও',
  'video' => 'ভিডিও',
  'pdf' => 'পিডিএফ',
  'book' || 'book_chapter' => 'বই',
  'article' => 'লেখা',
  _ => 'উপকরণ',
};
