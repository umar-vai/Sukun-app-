import 'package:flutter/material.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/ruqyah_audio_topics.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';

/// Browse the existing published/RLS-authorized material by listening topic.
/// This changes navigation only; no media source, publication status or rights.
class RuqyahTopicBrowser extends StatefulWidget {
  const RuqyahTopicBrowser({
    required this.resources,
    required this.onOpenResource,
    required this.onOpenAyat,
    super.key,
  });

  final List<ContentResource> resources;
  final ValueChanged<ContentResource> onOpenResource;
  final VoidCallback onOpenAyat;

  @override
  State<RuqyahTopicBrowser> createState() => _RuqyahTopicBrowserState();
}

class _RuqyahTopicBrowserState extends State<RuqyahTopicBrowser> {
  String _selected = 'all';

  @override
  Widget build(BuildContext context) {
    final audio = widget.resources.where((r) => r.type == 'audio').toList();
    final extra = widget.resources.where((r) => r.type != 'audio').toList();
    final topicOptions = ruqyahAudioTopics
        .where((t) => resourcesForRuqyahTopic(audio, t.slug).isNotEmpty)
        .toList();
    final selectedItems = resourcesForRuqyahTopic(widget.resources, _selected);
    final isGrouped = _selected == 'all' || _selected == 'ruqyah-audio';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topicStrip(ruqyahMainTopics, 'ধরন'),
        if (topicOptions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _topicStrip(topicOptions, 'বিষয়'),
        ],
        const SizedBox(height: 18),
        if (_selected == 'all' || _selected == 'ruqyah-ayat') ...[
          OutlinedButton.icon(
            key: const Key('ruqyah-open-ayat'),
            onPressed: widget.onOpenAyat,
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('রুকইয়াহ আয়াত পড়ুন'),
          ),
          const SizedBox(height: 12),
        ],
        if (isGrouped) ...[
          if (extra.isNotEmpty) ...[
            _sectionTitle('আয়াত ও গাইড', extra.length),
            const SizedBox(height: 8),
            for (final item in extra.take(2)) _item(item),
            const SizedBox(height: 6),
          ],
          for (final topic in ruqyahAudioTopics)
            if (audio.any((r) => ruqyahPrimaryBrowseTopic(r) == topic.slug))
              _group(topic, audio),
          if (audio.isEmpty && extra.isEmpty)
            const AppEmptyState(title: 'এখনো কোনো অডিও নেই'),
        ] else ...[
          if (selectedItems.isEmpty)
            AppEmptyState(
              title: _selected == 'ruqyah-self-guide'
                  ? 'এখনো প্রকাশিত গাইড নেই'
                  : _selected == 'ruqyah-ayat'
                  ? 'নির্বাচিত আয়াত উপরের লিংকে দেখুন'
                  : 'এই বিভাগে এখনো অডিও নেই',
            )
          else ...[
            _sectionTitle(_selectedTitle, selectedItems.length),
            const SizedBox(height: 8),
            for (final item in selectedItems) _item(item),
          ],
        ],
      ],
    );
  }

  String get _selectedTitle {
    for (final topic in [...ruqyahMainTopics, ...ruqyahAudioTopics]) {
      if (topic.slug == _selected) return topic.titleBn;
    }
    return 'রুকইয়াহ';
  }

  Widget _topicStrip(List<RuqyahBrowseTopic> topics, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final topic in topics) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: KeyedSubtree(
                    key: Key('ruqyah-filter-${topic.slug}'),
                    child: SukunFilterPill(
                      label: topic.titleBn,
                      selected: _selected == topic.slug,
                      onTap: () => setState(() => _selected = topic.slug),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _group(RuqyahBrowseTopic topic, List<ContentResource> audio) {
    final matches = audio
        .where((r) => ruqyahPrimaryBrowseTopic(r) == topic.slug)
        .toList();
    return Padding(
      key: Key('ruqyah-group-${topic.slug}'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle(topic.titleBn, matches.length)),
              if (matches.length > 2)
                TextButton(
                  key: Key('ruqyah-show-${topic.slug}'),
                  onPressed: () => setState(() => _selected = topic.slug),
                  child: const Text('সব দেখুন'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in matches.take(2)) _item(item),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, int count) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        '$count',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ],
  );

  Widget _item(ContentResource item) => Padding(
    key: Key('ruqyah-item-${item.id}'),
    padding: const EdgeInsets.only(bottom: 8),
    child: ResourceCard(
      resource: item,
      onTap: () => widget.onOpenResource(item),
    ),
  );
}
