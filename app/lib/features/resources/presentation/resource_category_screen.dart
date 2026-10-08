import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';
import 'package:sukun_life/features/resources/presentation/youtube_player_screen.dart';
import 'package:sukun_life/features/resources/domain/video_navigation.dart';

/// A separate destination for a published-resource category, not an inline
/// filter below the hub's grid. The same surface works for guests and patients.
class ResourceCategoryScreen extends ConsumerStatefulWidget {
  const ResourceCategoryScreen({super.key, required this.section});

  final ResourceSection section;

  @override
  ConsumerState<ResourceCategoryScreen> createState() =>
      _ResourceCategoryScreenState();
}

class _ResourceCategoryScreenState
    extends ConsumerState<ResourceCategoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late Future<List<ContentResource>> _resources;

  @override
  void initState() {
    super.initState();
    _resources = _load();
  }

  Future<List<ContentResource>> _load() => ref
      .read(resourcesRepositoryProvider)
      .browseResources(
        query: _searchController.text.trim(),
        types: widget.section.types,
        categoryPrefixes: widget.section.categoryPrefixes,
      );

  Future<void> _refresh() async {
    _debounce?.cancel();
    final next = _load();
    setState(() => _resources = next);
    try {
      await next;
    } catch (_) {
      // FutureBuilder renders the appropriate retry state.
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _refresh();
    });
  }

  void _openResource(ContentResource resource) {
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
    final section = widget.section;
    return Scaffold(
      appBar: AppBar(title: Text(section.titleBn)),
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
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ContentResource>>(
                future: _resources,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoadingState(label: 'উপকরণ আনা হচ্ছে…');
                  }
                  if (snapshot.hasError) {
                    return AppErrorState(
                      message: 'উপকরণ আনা যাচ্ছে না। আবার চেষ্টা করুন।',
                      onRetry: _refresh,
                    );
                  }
                  final items = snapshot.data ?? const <ContentResource>[];
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
