import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/ruqyah_audio_topics.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';

/// Each topic opens a dedicated route instead of expanding the same page.
class RuqyahTopicBrowser extends StatelessWidget {
  const RuqyahTopicBrowser({
    required this.resources,
    required this.onOpenResource,
    required this.onOpenAyat,
    this.topicSlug,
    super.key,
  });

  final List<ContentResource> resources;
  final ValueChanged<ContentResource> onOpenResource;
  final VoidCallback onOpenAyat;
  final String? topicSlug;

  static String titleFor(String? slug) {
    for (final topic in [...ruqyahMainTopics, ...ruqyahAudioTopics]) {
      if (topic.slug == slug) return topic.titleBn;
    }
    return 'রুকইয়াহ';
  }

  @override
  Widget build(BuildContext context) {
    if (topicSlug == null) return _index(context);
    final known = [...ruqyahMainTopics, ...ruqyahAudioTopics]
        .any((topic) => topic.slug == topicSlug);
    if (!known) {
      return const AppEmptyState(
        title: 'বিভাগ পাওয়া যায়নি',
        message: 'অন্য বিভাগ দেখুন।',
      );
    }
    final items = resourcesForRuqyahTopic(resources, topicSlug!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topicSlug == 'all' || topicSlug == 'ruqyah-ayat') ...[
          OutlinedButton.icon(
            key: const Key('ruqyah-open-ayat'),
            onPressed: onOpenAyat,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('রুকইয়াহ আয়াত পড়ুন'),
          ),
          const SizedBox(height: 14),
        ],
        if (items.isEmpty)
          const AppEmptyState(
            title: 'এই বিভাগে এখনো উপকরণ নেই',
            message: 'অন্য বিভাগ দেখুন।',
          )
        else
          for (final resource in items)
            Padding(
              key: Key('ruqyah-item-${resource.id}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: ResourceCard(
                resource: resource,
                onTap: () => onOpenResource(resource),
              ),
            ),
      ],
    );
  }

  Widget _index(BuildContext context) {
    final audio = resources.where((resource) => resource.type == 'audio')
        .toList(growable: false);
    final mainOptions = <RuqyahBrowseTopic>[
      ...ruqyahMainTopics,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'উপকরণ',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final topic in mainOptions) ...[
          _topicCard(
            context,
            topic: topic,
            count: resourcesForRuqyahTopic(resources, topic.slug).length,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        Text(
          'বিষয় অনুযায়ী অডিও',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final topic in ruqyahAudioTopics) ...[
          _topicCard(
            context,
            topic: topic,
            count: resourcesForRuqyahTopic(audio, topic.slug).length,
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
        onTap: () => context.push('/resources/ruqyah/${topic.slug}'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(Icons.headphones_rounded, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  topic.titleBn,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$count',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
