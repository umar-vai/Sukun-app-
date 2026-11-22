import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/features/resources/presentation/quran_continue_card.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/media_library/presentation/audio_library_actions.dart';
import 'package:sukun_life/features/resources/presentation/compact_audio_resource_card.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';
import 'package:sukun_life/features/resources/domain/resource_search.dart';
import 'package:sukun_life/features/resources/domain/resource_search_documents.dart';
import 'package:sukun_life/features/resources/presentation/live_search_suggestions.dart';
import 'package:sukun_life/features/resources/presentation/youtube_player_screen.dart';
import 'package:sukun_life/features/resources/presentation/book_audio_external_links_dialog.dart';
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
  /// Every published kind people search across. Qur'an ayat have their own
  /// reader and are not loaded into the search catalog.
  static const searchableTypes = {
    'hadith',
    'dua',
    'amal',
    'audio',
    'guide',
    'pdf',
    'book',
    'book_chapter',
    'article',
    'video',
  };

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Future<List<SearchDocument<ContentResource>>>? _catalog;
  Timer? _searchDebounce;
  String _query = '';
  String _kind = 'all';
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (!mounted) return;
      setState(() => _showSuggestions = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _backendUnavailable =>
      ref.read(resourcesRepositoryProvider) is UnavailableResourcesRepository;

  /// The hub never loads the catalog until someone searches. The first
  /// search loads every authorized published item once (cached by the
  /// repository), and each keystroke after that filters it instantly.
  Future<List<SearchDocument<ContentResource>>> _ensureCatalog() {
    return _catalog ??= ref
        .read(resourcesRepositoryProvider)
        .browseResources(types: searchableTypes)
        .then(
          (items) => [for (final item in items) resourceSearchDocument(item)],
        );
  }

  Future<void> _refresh() async {
    _searchDebounce?.cancel();
    setState(() {
      _catalog = null;
      _query = _searchController.text.trim();
    });
    if (_query.isEmpty || _backendUnavailable) return;
    try {
      await _ensureCatalog();
    } catch (_) {
      // The FutureBuilder presents the friendly retry state.
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    final text = _searchController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _query = '';
        _kind = 'all';
      });
      return;
    }
    if (!_backendUnavailable) _ensureCatalog();
    // A very short pause keeps typing smooth on slower phones.
    _searchDebounce = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      setState(() {
        _query = text;
        _showSuggestions = _searchFocus.hasFocus;
      });
    });
  }

  void _setQuery(String value) {
    _searchDebounce?.cancel();
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {
      _query = value.trim();
      _kind = 'all';
    });
    if (!_backendUnavailable && _query.isNotEmpty) _ensureCatalog();
  }

  void _clearSearch() {
    _searchController.clear();
    _setQuery('');
  }

  void _showAllResults() {
    _searchFocus.unfocus();
    setState(() => _showSuggestions = false);
  }

  void _onSuggestion(SearchSuggestion<ContentResource> suggestion) {
    final item = suggestion.item;
    if (item != null) {
      _searchFocus.unfocus();
      _openSearchResult(item);
      return;
    }
    _setQuery(suggestion.label);
    _showAllResults();
  }

  Future<void> _openBookAudioLinks() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const BookAudioExternalLinksDialog(),
    );
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
    final isPatient = ref.read(appSessionProvider).value?.isPatient == true;
    context.push(
      widget.embedded && isPatient
          ? '/patient/resources/${resource.id}'
          : '/resources/${resource.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    // This is a public browser route, which may remain mounted after logout.
    // Do not retain previous Patient/Member query results in the same tab.
    ref.listen<AsyncValue<AppSession>>(appSessionProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      // Initial loading -> Guest is not an account switch.
      if (before?.userId == null && after?.userId == null) return;
      if (before?.userId != after?.userId || before?.role != after?.role) {
        _refresh();
      }
    });
    final repository = ref.watch(resourcesRepositoryProvider);
    final backendUnavailable = repository is UnavailableResourcesRepository;
    final hasSearch = !backendUnavailable && _query.isNotEmpty;
    final content = RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverList.list(
              children: [
                SukunPageIntro(
                  title: 'ইসলামিক পাঠ ও অডিও',
                  subtitle: 'কুরআন, হাদিস, দোয়া ও রুকইয়াহ',
                  trailing: const SukunIconBadge(
                    icon: Icons.auto_stories_outlined,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 12),
                // Admin tools stay available but quiet, so the library reads
                // the same for staff as for patients.
                if (ref.watch(appSessionProvider).value?.isSuperAdmin == true)
                  Wrap(
                    key: const Key('resources-admin-tools'),
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => context.push('/admin/content/new'),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('নতুন কনটেন্ট যোগ করুন'),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/admin/content'),
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('কনটেন্ট পরিচালনা'),
                      ),
                    ],
                  ),
                const SizedBox(height: SukunSpace.md),
                if (backendUnavailable)
                  SukunSurface(
                    tone: SukunSurfaceTone.soft,
                    showBorder: false,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: SukunColors.deepTide,
                        ),
                        SizedBox(width: 10),
                        Expanded(child: Text('এখন কিছু দেখানো যাচ্ছে না।')),
                      ],
                    ),
                  )
                else
                  SukunSearchField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    hintText: 'দোয়া, অডিও, পিডিএফ বা বিষয় লিখুন',
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) {
                      _setQuery(_searchController.text);
                      _showAllResults();
                    },
                    onClear: _clearSearch,
                  ),
                if (!hasSearch) ..._browseChildren(),
              ],
            ),
          ),
          if (hasSearch) _searchResultsSliver(),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('ইসলামিক পাঠ ও অডিও')),
      body: content,
    );
  }

  List<Widget> _browseChildren() => [
    const SizedBox(height: SukunSpace.lg),
    const QuranContinueCard(),
    const SizedBox(height: SukunSpace.md),
    Row(
      key: const Key('resources-quick-links'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _QuickLink(
            icon: Icons.library_music_outlined,
            label: 'আমার প্লেলিস্ট ও অফলাইন ডাউনলোড',
            onTap: () => context.push('/my-media'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickLink(
            icon: Icons.headphones_outlined,
            label: 'রুকইয়াহ অডিও',
            onTap: _openBookAudioLinks,
          ),
        ),
      ],
    ),
    const SizedBox(height: SukunSpace.sectionLarge),
    SukunSectionHeader(title: 'বিষয় অনুযায়ী দেখুন'),
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
            mainAxisExtent: 84,
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
  ];

  Widget _searchResultsSliver() {
    return FutureBuilder<List<SearchDocument<ContentResource>>>(
      future: _ensureCatalog(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 160,
              child: AppLoadingState(label: 'অনুসন্ধান করা হচ্ছে…'),
            ),
          );
        }
        if (snapshot.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: AppErrorState(
              message: 'পাঠ আনা যাচ্ছে না। আবার চেষ্টা করুন।',
              onRetry: _refresh,
            ),
          );
        }
        final matches = rankSearch(snapshot.data!, _query);
        final counts = searchKindCounts(matches.map((item) => item.type));
        final kind = (counts[_kind] ?? 0) > 0 ? _kind : 'all';
        final visible = [
          for (final item in matches)
            if (searchKindAccepts(kind, item.type)) item,
        ];
        final suggestions = buildSearchSuggestions<ContentResource>(
          query: _query,
          rankedMatches: matches,
          titleOf: resourceDisplayTitle,
          kindOf: (item) => searchKindLabel(item.type),
          categoryOf: resourceCategoryLabel,
        );
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: SliverList.list(
            children: [
              if (_showSuggestions) ...[
                LiveSearchSuggestionList<ContentResource>(
                  query: _query,
                  suggestions: suggestions,
                  totalMatches: matches.length,
                  onSelect: _onSuggestion,
                  onShowAll: _showAllResults,
                  iconFor: (suggestion) => suggestion.item == null
                      ? Icons.folder_open_rounded
                      : resourceTypeIcon(suggestion.item!.type),
                ),
                const SizedBox(height: 18),
              ],
              SukunSectionHeader(
                title: matches.isEmpty
                    ? 'অনুসন্ধানের ফলাফল'
                    : 'অনুসন্ধানের ফলাফল · ${matches.length}টি',
              ),
              const SizedBox(height: 10),
              if (matches.isEmpty)
                AppEmptyState(
                  title: 'কোনো পাঠ পাওয়া যায়নি',
                  message: 'অন্য শব্দ বা বানানে আবার খুঁজুন।',
                )
              else ...[
                SearchKindChips(
                  counts: counts,
                  selected: kind,
                  onSelected: (value) => setState(() => _kind = value),
                ),
                const SizedBox(height: 12),
                for (final resource in visible) ...[
                  ResourceCard(
                    key: Key('search-result-${resource.id}'),
                    resource: resource,
                    onTap: () => _openSearchResult(resource),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.onTap});

  final ResourceSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SukunSurface(
      tone: SukunSurfaceTone.white,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          SukunIconBadge(icon: section.icon, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.titleBn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SukunTypography.banglaBody(
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: SukunColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 96,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    if (AudioLibraryActions.supports(resource.linkedResource)) {
      return CompactAudioResourceCard(resource: resource, onTap: onTap);
    }
    return SukunSurface(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBlogResourceSlug(resource.slug) &&
              resource.thumbnailUrl?.startsWith('https://') == true) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                resource.thumbnailUrl!,
                width: double.infinity,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SukunIconBadge(icon: resourceTypeIcon(resource.type)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.titleBn?.isNotEmpty == true
                          ? resource.titleBn!
                          : resource.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: resource.titleBn?.isNotEmpty == true
                          ? SukunTypography.banglaDisplay(
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            )
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData resourceTypeIcon(String type) => switch (type) {
  'quran' => Icons.auto_stories_outlined,
  'hadith' => Icons.format_quote_outlined,
  'dua' || 'amal' => Icons.favorite_outline,
  'audio' => Icons.headphones_outlined,
  'video' => Icons.ondemand_video_outlined,
  'pdf' || 'book' || 'book_chapter' => Icons.picture_as_pdf_outlined,
  _ => Icons.article_outlined,
};

/// Compact shortcut tile for secondary library destinations.
