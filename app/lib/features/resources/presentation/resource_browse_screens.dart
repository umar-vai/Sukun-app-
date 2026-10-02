import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
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
            return AppErrorState(message: snapshot.error.toString());
          }
          final surahs = snapshot.data ?? const <QuranSurahSummary>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Text(
                'সূরা ও আয়াত',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Browse only verified, published Qur’an text and approved translations.',
              ),
              const SizedBox(height: 18),
              Card(
                color: SukunColors.mist,
                child: ListTile(
                  leading: const Icon(Icons.collections_bookmark_outlined),
                  title: const Text('Selected & Ruqyah Ayat collections'),
                  subtitle: const Text('নির্বাচিত ও রুকইয়াহ আয়াত'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/resources/quran/collections'),
                ),
              ),
              const SizedBox(height: 18),
              Text('Surahs', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (surahs.isEmpty)
                const AppEmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: 'No verified Surahs published yet',
                  message: 'A Super Admin must verify and publish canonical Ayat before they appear here.',
                )
              else
                for (final surah in surahs)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: SukunColors.mist,
                        foregroundColor: SukunColors.deepTide,
                        child: Text('${surah.surahNumber}'),
                      ),
                      title: Text(surah.nameBn ?? surah.name),
                      subtitle: Text(
                        '${surah.name}${surah.nameBn == null ? '' : ' • ${surah.ayahCount} published Ayat'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/resources/quran/${surah.surahNumber}'),
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
            return AppErrorState(message: snapshot.error.toString());
          }
          final collections = snapshot.data ?? const <ContentCollection>[];
          if (collections.isEmpty) {
            return const AppEmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'No Ayat collections published yet',
              message: 'Collections reuse verified canonical Ayat and never duplicate Qur’an text.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: collections.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final collection = collections[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(
                    backgroundColor: SukunColors.mist,
                    child: Icon(Icons.bookmarks_outlined),
                  ),
                  title: Text(collection.titleBn ?? collection.title),
                  subtitle: Text(
                    collection.summary ??
                        (collection.type == 'ruqyah_ayat'
                            ? 'Ruqyah Ayat'
                            : 'Selected Ayat'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/resources/quran/collections/${collection.id}',
                  ),
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
            return AppErrorState(message: snapshot.error.toString());
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
              Text(
                details.collection.titleBn ?? details.collection.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (details.collection.titleBn != null)
                Text(details.collection.title),
              if (details.collection.summary case final summary?) ...[
                const SizedBox(height: 8),
                Text(summary),
              ],
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
            return AppErrorState(message: snapshot.error.toString());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Text(
                'হাদিসের বিষয়',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Topics are created by the CMS. Only verified and published Hadith are shown.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All topics'),
                    selected: _topicSlug == null,
                    onSelected: (_) => setState(() => _topicSlug = null),
                  ),
                  for (final topic in data.$1)
                    ChoiceChip(
                      label: Text(
                        '${topic.nameBn ?? topic.name} (${topic.resourceCount})',
                      ),
                      selected: _topicSlug == topic.slug,
                      onSelected: (_) =>
                          setState(() => _topicSlug = topic.slug),
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
            return AppErrorState(message: snapshot.error.toString());
          }
          final resources = snapshot.data ?? const <ContentResource>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Text(
                isDua ? 'দুআ ও আযকার' : 'রুকইয়াহ',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                isDua
                    ? 'Browse approved Dua and Azkar by daily-life category.'
                    : 'General resources are separate from prescribed patient care plans.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedSlug == null,
                    onSelected: (_) => setState(() => _selectedSlug = null),
                  ),
                  for (final entry in _entries)
                    ChoiceChip(
                      label: Text(entry.titleBn),
                      selected: _selectedSlug == entry.slug,
                      onSelected: (_) =>
                          setState(() => _selectedSlug = entry.slug),
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
      return AppErrorState(message: snapshot.error.toString());
    }
    final resources = snapshot.data ?? const <ContentResource>[];
    if (resources.isEmpty) {
      return AppEmptyState(
        title: emptyTitle,
        message: 'Only verified and published resources appear here.',
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
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: leadingLabel == null
            ? null
            : CircleAvatar(
                backgroundColor: SukunColors.mist,
                child: Text(leadingLabel!),
              ),
        title: Text(resource.titleBn ?? resource.title),
        subtitle: reference == null || reference.isEmpty
            ? (resource.summary == null ? null : Text(resource.summary!))
            : Text(reference),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/resources/${resource.id}'),
      ),
    );
  }
}
