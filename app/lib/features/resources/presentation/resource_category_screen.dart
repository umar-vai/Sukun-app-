import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/media/resource_media.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/resources/presentation/audio_player_screen.dart';
import 'package:sukun_life/features/media_library/presentation/audio_library_actions.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';
import 'package:sukun_life/features/resources/presentation/youtube_player_screen.dart';
import 'package:sukun_life/features/resources/domain/video_navigation.dart';

/// A separate destination for a published-resource category, not an inline
/// filter below the hub's grid. The same surface works for guests and patients.
class ResourceCategoryScreen extends ConsumerStatefulWidget {
  const ResourceCategoryScreen({
    super.key,
    required this.section,
    this.loadAudioResource,
  });

  final ResourceSection section;

  /// Lets widget tests verify navigation without requesting remote audio.
  final Future<void> Function(LinkedResource)? loadAudioResource;

  @override
  ConsumerState<ResourceCategoryScreen> createState() =>
      _ResourceCategoryScreenState();
}

class _ResourceCategoryScreenState
    extends ConsumerState<ResourceCategoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _searchPending = false;
  // Only the merged shelf has inner tabs; all other resource categories keep
  // their existing single-list layout and search behavior.
  int _selectedLibraryTab = 0;
  late Future<List<ContentResource>> _resources;

  bool get _hasLibraryTabs => widget.section.slug == 'books-articles';

  Set<String> get _activeTypes => _hasLibraryTabs
      ? (_selectedLibraryTab == 0
            ? const {'book', 'book_chapter', 'pdf'}
            : const {'article', 'guide'})
      : widget.section.types;

  void _selectLibraryTab(int tab) {
    if (!_hasLibraryTabs || tab == _selectedLibraryTab) return;
    _debounce?.cancel();
    setState(() => _selectedLibraryTab = tab);
    _refresh();
  }

  @override
  void initState() {
    super.initState();
    final unavailable =
        ref.read(resourcesRepositoryProvider) is UnavailableResourcesRepository;
    _resources = unavailable
        ? Future.value(const <ContentResource>[])
        : _load();
  }

  Future<List<ContentResource>> _load() async {
    final items = await ref
        .read(resourcesRepositoryProvider)
        .browseResources(
          query: _searchController.text.trim(),
          types: _activeTypes,
          categoryPrefixes: widget.section.categoryPrefixes,
        );
    // Blog posts are articles in the same RLS-protected CMS, but have their
    // own public shelf. Exclude them from Books & Articles.
    return items
        .where((item) {
          final blog = isBlogResourceSlug(item.slug);
          if (widget.section.slug == 'blog') return blog;
          if (_hasLibraryTabs) {
            return !blog && _activeTypes.contains(item.type);
          }
          return !blog;
        })
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    final backendUnavailable =
        ref.read(resourcesRepositoryProvider) is UnavailableResourcesRepository;
    if (backendUnavailable) return;
    _debounce?.cancel();
    final next = _load();
    setState(() {
      _resources = next;
      _searchPending = false;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder renders the appropriate retry state.
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    // Hide results from an old query immediately, rather than showing stale
    // tiles during the debounce window (including quick edits and clearing).
    if (_searchController.text.trim().isEmpty) {
      _refresh();
      return;
    }
    setState(() => _searchPending = true);
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _refresh();
    });
  }

  void _openResource(ContentResource resource) {
    // A playable audio tile opens the existing full player immediately,
    // without visiting the source/listen intermediary. Only resources
    // returned by this role-filtered repository list reach this action.
    if (resource.type == 'audio' &&
        resolveResourceMedia(resource.linkedResource)?.kind ==
            ResourceMediaKind.audio) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AudioPlayerScreen(
            resource: resource.linkedResource,
            loadResource: widget.loadAudioResource,
          ),
        ),
      );
      return;
    }
    // A video tile is itself the playback action. Do not route through an
    // intermediate resource detail page that requires a second tap.
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
    final isPatient = ref.read(appSessionProvider).value?.isPatient ?? false;
    final path = isPatient ? '/patient/resources' : '/resources';
    context.push('$path/${Uri.encodeComponent(resource.id)}');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
    final section = widget.section;
    final repository = ref.watch(resourcesRepositoryProvider);
    final backendUnavailable = repository is UnavailableResourcesRepository;
    return Scaffold(
      appBar: AppBar(
        title: Text(section.titleBn),
        actions: const [AudioLibraryShortcut(compact: true)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SukunIconBadge(icon: section.icon, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          section.titleBn,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  if (_hasLibraryTabs) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        key: const Key('books-articles-inner-tabs'),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<int>(
                            value: 0,
                            label: Text('বই'),
                            icon: Icon(Icons.menu_book_outlined),
                          ),
                          ButtonSegment<int>(
                            value: 1,
                            label: Text('আর্টিকেল'),
                            icon: Icon(Icons.article_outlined),
                          ),
                        ],
                        selected: {_selectedLibraryTab},
                        onSelectionChanged: (selected) =>
                            _selectLibraryTab(selected.first),
                      ),
                    ),
                  ],
                  if (!backendUnavailable) ...[
                    const SizedBox(height: 14),
                    SukunSearchField(
                      controller: _searchController,
                      hintText: 'এই বিভাগে খুঁজুন',
                      onChanged: _onSearch,
                      onSubmitted: (_) => _refresh(),
                      onClear: () {
                        _searchController.clear();
                        _refresh();
                      },
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: backendUnavailable
                  ? AppEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'এখন উপকরণ দেখানো যাচ্ছে না',
                      message: 'পরে আবার চেষ্টা করুন।',
                    )
                  : _searchPending
                  ? const AppLoadingState(label: 'অনুসন্ধান করা হচ্ছে…')
                  : FutureBuilder<List<ContentResource>>(
                      future: _resources,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const AppLoadingState(
                            label: 'উপকরণ আনা হচ্ছে…',
                          );
                        }
                        if (snapshot.hasError) {
                          return AppErrorState(
                            message: 'উপকরণ আনা যাচ্ছে না। আবার চেষ্টা করুন।',
                            onRetry: _refresh,
                          );
                        }
                        final items =
                            snapshot.data ?? const <ContentResource>[];
                        if (items.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(20),
                              children: const [
                                AppEmptyState(
                                  title: 'কোনো উপকরণ পাওয়া যায়নি',
                                  message: 'এই বিভাগে এখনো কোনো উপকরণ নেই।',
                                ),
                              ],
                            ),
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                            itemCount: items.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) => ResourceCard(
                              resource: items[index],
                              onTap: () => _openResource(items[index]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
