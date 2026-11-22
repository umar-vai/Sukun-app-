import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/ruqyah_audio_topics.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';
import 'package:sukun_life/features/resources/presentation/self_ruqyah_guide_index.dart';

/// Each topic opens a dedicated route instead of expanding the same page.
class RuqyahTopicBrowser extends StatelessWidget {
  const RuqyahTopicBrowser({
    required this.resources,
    required this.onOpenResource,
    required this.onOpenAyat,
    this.topicSlug,
    this.guideChapterNumber,
    this.guideGroupSlug,
    super.key,
  });

  final List<ContentResource> resources;
  final ValueChanged<ContentResource> onOpenResource;
  final VoidCallback onOpenAyat;
  final String? topicSlug;
  final int? guideChapterNumber;
  final String? guideGroupSlug;

  static String titleFor(String? slug) {
    for (final topic in _allTopics) {
      if (topic.slug == slug) return topic.titleBn;
    }
    return 'রুকইয়াহ';
  }

  @override
  Widget build(BuildContext context) {
    if (topicSlug == null) return _index(context);
    final known = _allTopics.any((topic) => topic.slug == topicSlug);
    if (!known) {
      return const AppEmptyState(
        title: 'বিভাগ পাওয়া যায়নি',
        message: 'অন্য বিভাগ দেখুন।',
      );
    }
    if (topicSlug == 'ruqyah-audio') return _audioShelves(context);
    if (topicSlug == 'all') return _allGrouped(context);
    final items = resourcesForRuqyahTopic(resources, topicSlug!);
    if (topicSlug == 'ruqyah-self-guide') {
      return SelfRuqyahGuideIndex(
        resources: items,
        onOpenResource: onOpenResource,
        chapterNumber: guideChapterNumber,
        groupSlug: guideGroupSlug,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topicSlug == 'ruqyah-ayat') ...[
          _openAyatButton(),
          const SizedBox(height: 14),
        ],
        if (items.isEmpty)
          const AppEmptyState(
            title: 'এই বিভাগে এখনো পাঠ নেই',
            message: 'অন্য বিভাগ দেখুন।',
          )
        else
          ..._itemCards(items),
      ],
    );
  }

  Widget _openAyatButton() => OutlinedButton.icon(
    key: const Key('ruqyah-open-ayat'),
    onPressed: onOpenAyat,
    icon: const Icon(Icons.menu_book_outlined),
    label: const Text('রুকইয়াহ আয়াত পড়ুন'),
  );

  List<Widget> _itemCards(List<ContentResource> items) => [
    for (final resource in items)
      Padding(
        key: Key('ruqyah-item-${resource.id}'),
        padding: const EdgeInsets.only(bottom: 10),
        child: ResourceCard(
          resource: resource,
          onTap: () => onOpenResource(resource),
        ),
      ),
  ];

  List<ContentResource> get _audio => resources
      .where((resource) => resource.type == 'audio')
      .toList(growable: false);

  /// The audio library the way RuqyahBD shows it: the main download page
  /// groups, then "আরও কিছু অডিও", each group opening its own list.
  Widget _audioShelves(BuildContext context) {
    final audio = _audio;
    final ungrouped = resourcesForRuqyahTopic(
      audio,
      ruqyahUngroupedAudioTopic.slug,
    ).length;
    final children = <Widget>[];
    for (final shelf in ruqyahAudioShelves) {
      final topics = [
        for (final topic in shelf.topics)
          if (resourcesForRuqyahTopic(audio, topic.slug).isNotEmpty) topic,
      ];
      if (topics.isEmpty) continue;
      children
        ..add(_shelfHeader(context, shelf.titleBn))
        ..add(const SizedBox(height: 12));
      for (final topic in topics) {
        children
          ..add(
            _topicCard(
              context,
              topic: topic,
              count: resourcesForRuqyahTopic(audio, topic.slug).length,
            ),
          )
          ..add(const SizedBox(height: 10));
      }
      children.add(const SizedBox(height: 14));
    }
    if (ungrouped > 0) {
      children
        ..add(_shelfHeader(context, 'অন্যান্য'))
        ..add(const SizedBox(height: 12))
        ..add(
          _topicCard(
            context,
            topic: ruqyahUngroupedAudioTopic,
            count: ungrouped,
          ),
        );
    }
    if (children.isEmpty) {
      return const AppEmptyState(
        title: 'এই বিভাগে এখনো অডিও নেই',
        message: 'অন্য বিভাগ দেখুন।',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// Everything in one scroll, under the same headings as the index.
  Widget _allGrouped(BuildContext context) {
    final audio = _audio;
    final children = <Widget>[_openAyatButton(), const SizedBox(height: 16)];
    void addGroup(String title, List<ContentResource> items) {
      if (items.isEmpty) return;
      children
        ..add(_shelfHeader(context, '$title · ${items.length}টি'))
        ..add(const SizedBox(height: 10))
        ..addAll(_itemCards(items))
        ..add(const SizedBox(height: 10));
    }

    for (final topic in ruqyahLibraryTopics) {
      addGroup(topic.titleBn, resourcesForRuqyahTopic(audio, topic.slug));
    }
    addGroup(
      ruqyahUngroupedAudioTopic.titleBn,
      resourcesForRuqyahTopic(audio, ruqyahUngroupedAudioTopic.slug),
    );
    addGroup(
      'সেলফ-রুকইয়াহ গাইড',
      resourcesForRuqyahTopic(resources, 'ruqyah-self-guide'),
    );
    addGroup('অন্যান্য', [
      for (final resource in resources)
        if (resource.type != 'audio' &&
            !ruqyahBrowseTopicMembership(resource)
                .contains('ruqyah-self-guide'))
          resource,
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _shelfHeader(BuildContext context, String title) => Text(
    title,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _index(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'বিভাগসমূহ',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final topic in ruqyahMainTopics) ...[
          _topicCard(
            context,
            topic: topic,
            count: resourcesForRuqyahTopic(resources, topic.slug).length,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _topicCard(
    BuildContext context, {
    required RuqyahBrowseTopic topic,
    required int count,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('ruqyah-filter-${topic.slug}'),
        onTap: () => context.go('/resources/ruqyah/${topic.slug}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(_iconForTopic(topic.slug), color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  topic.titleBn,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                topic.slug == 'ruqyah-self-guide'
                    ? '৪ অধ্যায়'
                    : topic.slug == 'ruqyah-ayat'
                    ? 'বিষয়সমূহ'
                    : '$count',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Older title-based audio topic links keep working after the library groups.
const _allTopics = <RuqyahBrowseTopic>[
  ...ruqyahMainTopics,
  ...ruqyahLibraryTopics,
  ruqyahUngroupedAudioTopic,
  ...ruqyahAudioTopics,
];

IconData _iconForTopic(String slug) => switch (slug) {
  'ruqyah-ayat' => Icons.auto_stories_outlined,
  'ruqyah-self-guide' => Icons.menu_book_outlined,
  'all' => Icons.grid_view_rounded,
  _ => Icons.headphones_rounded,
};
