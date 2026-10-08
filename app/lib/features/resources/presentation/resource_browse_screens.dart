import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';

class QuranBrowserScreen extends ConsumerWidget {
  const QuranBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(resourcesRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Qur'an")),
      body: FutureBuilder<List<QuranSurahSummary>>(
        future: repository.browseSurahs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Loading Surahs');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
            );
          }
          final surahs = snapshot.data ?? const <QuranSurahSummary>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              const SukunPageIntro(
                eyebrow: 'Sourced scripture',
                title: "Qur'an",
                subtitle:
                    'সূরা ও আয়াত · Approved Arabic and Bangla sources only',
                trailing: SukunIconBadge(
                  icon: Icons.menu_book_rounded,
                  size: 54,
                ),
              ),
              const SizedBox(height: 18),
              SukunSurface(
                tone: SukunSurfaceTone.navy,
                showBorder: false,
                onTap: () => context.push('/resources/quran/collections'),
                child: const Row(
                  children: [
                    SukunIconBadge(
                      icon: Icons.collections_bookmark_outlined,
                      color: Colors.white,
                      backgroundColor: Color(0x3326B6EA),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected & Ruqyah Ayat',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'নির্বাচিত ও রুকইয়াহ আয়াত',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SukunSectionHeader(
                title: 'Surahs',
                subtitle: 'Canonical items grouped by Surah number.',
              ),
              const SizedBox(height: 8),
              if (surahs.isEmpty)
                const AppEmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: 'No Surahs published yet',
                  message: 'A Super Admin must add complete source metadata and publish canonical Ayat before they appear here.',
                )
              else
                for (final surah in surahs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SukunSurface(
                      padding: const EdgeInsets.all(16),
                      radius: 20,
                      onTap: () =>
                          context.push('/resources/quran/${surah.surahNumber}'),
                      child: Row(
                        children: [
                          SukunIconBadge(
                            icon: Icons.auto_stories_outlined,
                            size: 46,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  surah.nameBn ?? surah.name,
                                  style: SukunTypography.banglaBody(
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${surah.surahNumber} · ${surah.name} · ${surah.ayahCount} published Ayat',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: SukunColors.muted),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class QuranSurahScreen extends ConsumerWidget {
  const QuranSurahScreen({required this.surahNumber, super.key});

  final int surahNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Surah $surahNumber')),
      body: FutureBuilder<List<ContentResource>>(
        future: ref.read(resourcesRepositoryProvider).browseSurah(surahNumber),
        builder: (context, snapshot) => _ResourceFutureList(
          snapshot: snapshot,
          emptyTitle: 'No Ayat published for this Surah',
          itemBuilder: (resource) => _ResourceListTile(
            resource: resource,
            leadingLabel: resource.ayahNumber?.toString(),
          ),
        ),
      ),
    );
  }
}

class QuranCollectionsScreen extends ConsumerWidget {
  const QuranCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayat collections')),
      body: FutureBuilder<List<ContentCollection>>(
        future: ref
            .read(resourcesRepositoryProvider)
            .browseCollections(types: const {'selected_ayat', 'ruqyah_ayat'}),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Loading collections');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
            );
          }
          final collections = snapshot.data ?? const <ContentCollection>[];
          if (collections.isEmpty) {
            return const AppEmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'No Ayat collections published yet',
              message: 'Collections reuse sourced canonical Ayat and never duplicate Qur’an text.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: collections.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final collection = collections[index];
              return SukunSurface(
                padding: const EdgeInsets.all(16),
                radius: 20,
                onTap: () => context.push(
                  '/resources/quran/collections/${collection.id}',
                ),
                child: Row(
                  children: [
                    const SukunIconBadge(icon: Icons.bookmarks_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collection.titleBn ?? collection.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            collection.summary ??
                                (collection.type == 'ruqyah_ayat'
                                    ? 'Ruqyah Ayat'
                                    : 'Selected Ayat'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: SukunColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class QuranCollectionDetailScreen extends ConsumerWidget {
  const QuranCollectionDetailScreen({required this.collectionId, super.key});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayat collection')),
      body: FutureBuilder<ContentCollectionDetails?>(
        future: ref
            .read(resourcesRepositoryProvider)
            .getCollection(collectionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Loading collection');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
            );
          }
          final details = snapshot.data;
          if (details == null) {
            return const AppEmptyState(
              title: 'Collection unavailable',
              message: 'It may be unpublished or not visible to this account.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              SukunPageIntro(
                eyebrow: 'Ayat collection',
                title: details.collection.titleBn ?? details.collection.title,
                subtitle: details.collection.titleBn == null
                    ? details.collection.summary
                    : '${details.collection.title}${details.collection.summary == null ? '' : ' · ${details.collection.summary}'}',
                trailing: const SukunIconBadge(
                  icon: Icons.collections_bookmark_outlined,
                  size: 54,
                ),
              ),
              const SizedBox(height: 18),
              for (final resource in details.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ResourceListTile(resource: resource),
                ),
            ],
          );
        },
      ),
    );
  }
}

class HadithBrowserScreen extends ConsumerStatefulWidget {
  const HadithBrowserScreen({super.key});

  @override
  ConsumerState<HadithBrowserScreen> createState() =>
      _HadithBrowserScreenState();
}

class _HadithBrowserScreenState extends ConsumerState<HadithBrowserScreen> {
  String? _topicSlug;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(resourcesRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hadith by topic')),
      body: FutureBuilder<(List<ResourceTopic>, List<ContentResource>)>(
        future: _load(repository),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Loading Hadith topics');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              const SukunPageIntro(
                eyebrow: 'Sourced references',
                title: 'Hadith by topic',
                subtitle: 'হাদিসের বিষয় · Collection, book, number, and approved grading',
                trailing: SukunIconBadge(
                  icon: Icons.format_quote_rounded,
                  size: 54,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SukunFilterPill(
                    label: 'All topics',
                    selected: _topicSlug == null,
                    onTap: () => setState(() => _topicSlug = null),
                  ),
                  for (final topic in data.$1)
                    SukunFilterPill(
                      label:
                          '${topic.nameBn ?? topic.name} (${topic.resourceCount})',
                      selected: _topicSlug == topic.slug,
                      onTap: () => setState(() => _topicSlug = topic.slug),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (data.$2.isEmpty)
                const AppEmptyState(
                  title: 'No Hadith published in this topic',
                  message: 'Choose another topic or check again later.',
                )
              else
                for (final resource in data.$2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ResourceListTile(resource: resource),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<(List<ResourceTopic>, List<ContentResource>)> _load(
    ResourcesRepository repository,
  ) async {
    final topics = await repository.browseTopics(types: const {'hadith'});
    final resources = await repository.browseResources(
      types: const {'hadith'},
      categoryPrefixes: _topicSlug == null ? const {} : {_topicSlug!},
    );
    return (topics, resources);
  }
}

enum TaxonomyKind { duaAzkar, ruqyah }

class TaxonomyBrowserScreen extends ConsumerStatefulWidget {
  const TaxonomyBrowserScreen({required this.kind, super.key});

  final TaxonomyKind kind;

  @override
  ConsumerState<TaxonomyBrowserScreen> createState() =>
      _TaxonomyBrowserScreenState();
}

class _TaxonomyBrowserScreenState extends ConsumerState<TaxonomyBrowserScreen> {
  String? _selectedSlug;

  List<ResourceTaxonomyEntry> get _entries =>
      widget.kind == TaxonomyKind.duaAzkar ? duaAzkarTaxonomy : ruqyahTaxonomy;

  @override
  Widget build(BuildContext context) {
    final isDua = widget.kind == TaxonomyKind.duaAzkar;
    final types = isDua
        ? const {'dua', 'amal'}
        : const {'quran', 'amal', 'audio', 'guide'};
    final prefix = isDua ? 'dua-azkar' : 'ruqyah';
    return Scaffold(
      appBar: AppBar(title: Text(isDua ? 'Dua & Azkar' : 'Ruqyah')),
      body: FutureBuilder<List<ContentResource>>(
        future: ref
            .read(resourcesRepositoryProvider)
            .browseResources(
              types: types,
              categoryPrefixes: {_selectedSlug ?? prefix},
            ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Loading resources');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
            );
          }
          final resources = snapshot.data ?? const <ContentResource>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              SukunPageIntro(
                eyebrow: isDua ? 'Daily remembrance' : 'Faith-anchored care',
                title: isDua ? 'Dua & Azkar' : 'Ruqyah',
                subtitle: isDua
                    ? 'দুআ ও আযকার · Approved daily-life categories'
                    : 'রুকইয়াহ · General resources remain separate from prescribed care',
                trailing: SukunIconBadge(
                  icon: isDua
                      ? Icons.auto_awesome_rounded
                      : Icons.health_and_safety_outlined,
                  size: 54,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SukunFilterPill(
                    label: 'All',
                    selected: _selectedSlug == null,
                    onTap: () => setState(() => _selectedSlug = null),
                  ),
                  for (final entry in _entries)
                    SukunFilterPill(
                      label: entry.titleBn,
                      selected: _selectedSlug == entry.slug,
                      onTap: () => setState(() => _selectedSlug = entry.slug),
                    ),
                ],
              ),
              if (!isDua &&
                  (_selectedSlug == null ||
                      _selectedSlug == 'ruqyah-ayat')) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => context.push('/resources/quran/collections'),
                  icon: const Icon(Icons.collections_bookmark_outlined),
                  label: const Text('Open Ruqyah Ayat collections'),
                ),
              ],
              const SizedBox(height: 18),
              if (resources.isEmpty)
                const AppEmptyState(
                  title: 'No resources published in this category',
                  message: 'Only content visible to this account appears here.',
                )
              else
                for (final resource in resources)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ResourceListTile(resource: resource),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _ResourceFutureList extends StatelessWidget {
  const _ResourceFutureList({
    required this.snapshot,
    required this.emptyTitle,
    required this.itemBuilder,
  });

  final AsyncSnapshot<List<ContentResource>> snapshot;
  final String emptyTitle;
  final Widget Function(ContentResource) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const AppLoadingState(label: 'Loading resources');
    }
    if (snapshot.hasError) {
      return AppErrorState(message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।');
    }
    final resources = snapshot.data ?? const <ContentResource>[];
    if (resources.isEmpty) {
      return AppEmptyState(
        title: emptyTitle,
        message: 'Only published resources available to you appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: resources.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => itemBuilder(resources[index]),
    );
  }
}

class _ResourceListTile extends StatelessWidget {
  const _ResourceListTile({required this.resource, this.leadingLabel});

  final ContentResource resource;
  final String? leadingLabel;

  @override
  Widget build(BuildContext context) {
    final reference = switch (resource.type) {
      'quran' => resource.referenceText,
      'hadith' => [
        resource.collectionName,
        resource.bookName,
        resource.hadithNumber,
        resource.grade,
      ].whereType<String>().join(' • '),
      _ => resource.categoryName,
    };
    return SukunSurface(
      radius: 20,
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/resources/${resource.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leadingLabel == null
              ? SukunIconBadge(icon: _resourceIcon(resource.type), size: 46)
              : Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SukunColors.softBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    leadingLabel!,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: SukunColors.deepTide),
                  ),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.titleBn ?? resource.title,
                  style: SukunTypography.banglaBody(
                    textStyle: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (reference != null && reference.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reference,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: SukunColors.muted),
                  ),
                ] else if (resource.summary != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    resource.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: SukunColors.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        ],
      ),
    );
  }
}

IconData _resourceIcon(String type) => switch (type) {
  'quran' => Icons.menu_book_rounded,
  'hadith' => Icons.format_quote_rounded,
  'dua' || 'amal' => Icons.auto_awesome_rounded,
  'audio' => Icons.headphones_rounded,
  'video' => Icons.play_circle_outline_rounded,
  'pdf' || 'book' => Icons.library_books_outlined,
  _ => Icons.article_outlined,
};
