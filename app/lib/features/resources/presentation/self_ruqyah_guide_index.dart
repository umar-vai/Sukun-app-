import 'package:flutter/material.dart';
import 'package:sukun_life/core/widgets/sukun_glass.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

/// Source-table-of-contents navigation over existing published CMS records.
/// No book text or private data is embedded in the Flutter source.
class SelfRuqyahGuideGroup {
  const SelfRuqyahGuideGroup(
    this.chapter,
    this.slug,
    this.title,
    this.firstTopic,
    this.lastTopic,
  );

  final int chapter;
  final String slug;
  final String title;
  final int firstTopic;
  final int lastTopic;
}

const selfRuqyahChapterTitles = <String>[
  'প্রাথমিক আলোচনা',
  'প্যারানরমাল সমস্যা',
  'সেলফ রুকইয়াহ গাইড',
  'রুকইয়াহ পদ্ধতি',
];

const selfRuqyahChapterLabels = <String>[
  'প্রথম অধ্যায়',
  'দ্বিতীয় অধ্যায়',
  'তৃতীয় অধ্যায়',
  'চতুর্থ অধ্যায়',
];

/// Ranges follow the order of the four chapters and their original subjects.
/// Grouping changes navigation only; each source item remains unchanged.
const selfRuqyahGroups = <SelfRuqyahGuideGroup>[
  SelfRuqyahGuideGroup(1, 'introduction', 'রুকইয়াহ পরিচিতি', 1, 5),
  SelfRuqyahGuideGroup(
    1,
    'precautions',
    'প্রচলিত চিকিৎসা, তাবিজ ও সতর্কতা',
    6,
    9,
  ),
  SelfRuqyahGuideGroup(1, 'raqi', 'রাকি ও রুকইয়াহ গ্রহণ', 10, 13),
  SelfRuqyahGuideGroup(1, 'self', 'সেলফ রুকইয়াহ', 14, 15),
  SelfRuqyahGuideGroup(2, 'evil-eye', 'বদনজর', 1, 5),
  SelfRuqyahGuideGroup(2, 'sihr', 'জাদু', 6, 12),
  SelfRuqyahGuideGroup(2, 'jinn', 'জিন', 13, 18),
  SelfRuqyahGuideGroup(2, 'waswasa', 'ওয়াসওয়াসা', 19, 24),
  SelfRuqyahGuideGroup(2, 'home', 'বাড়ির সমস্যা ও করণীয়', 25, 27),
  SelfRuqyahGuideGroup(2, 'protection', 'জিন, জাদু ও নজর থেকে হেফাজত', 28, 28),
  SelfRuqyahGuideGroup(3, 'preparation', 'সেলফ রুকইয়াহর প্রস্তুতি', 1, 3),
  SelfRuqyahGuideGroup(3, 'food', 'পানি, মধু ও খাদ্য উপাদান', 4, 8),
  SelfRuqyahGuideGroup(3, 'herbs', 'হিজামা, পাতা ও ভেষজ', 9, 13),
  SelfRuqyahGuideGroup(3, 'materials', 'অন্যান্য উপকরণ', 14, 18),
  SelfRuqyahGuideGroup(3, 'spiritual', 'দুআ, সালাত ও আমল', 19, 26),
  SelfRuqyahGuideGroup(3, 'bathing', 'রুকইয়াহ গোসল', 27, 30),
  SelfRuqyahGuideGroup(3, 'questions', 'সাধারণ জিজ্ঞাসা', 31, 32),
  SelfRuqyahGuideGroup(3, 'women', 'নারীকেন্দ্রিক প্রশ্নোত্তর', 33, 37),
  SelfRuqyahGuideGroup(4, 'method', 'রুকইয়াহ করার পদ্ধতি', 1, 6),
  SelfRuqyahGuideGroup(4, 'dua', 'রুকইয়াহর দুআ', 7, 10),
  SelfRuqyahGuideGroup(4, 'basic-ayat', 'প্রাথমিক, জিন ও নজরের আয়াত', 11, 14),
  SelfRuqyahGuideGroup(4, 'sihr-ayat', 'জাদুর আয়াত', 15, 20),
  SelfRuqyahGuideGroup(4, 'shifa', 'শিফার আয়াত', 21, 21),
  SelfRuqyahGuideGroup(4, 'special-ayat', 'বিশেষ রুকইয়াহ আয়াত', 22, 28),
  SelfRuqyahGuideGroup(4, 'sihr-dua', 'জাদু নষ্টের দুআ', 29, 32),
  SelfRuqyahGuideGroup(4, 'daily', 'দৈনন্দিন মাসনুন আমল', 33, 36),
  SelfRuqyahGuideGroup(4, 'quick-reference', 'কুইক রুকইয়াহ ইনফো', 37, 37),
];

const _guidePath = '/resources/ruqyah/ruqyah-self-guide';

int? selfRuqyahTopicNumber(String? slug, int chapter) {
  if (chapter < 1 || chapter > 4 || slug == null) return null;
  final expression = RegExp(
    '^srg2024-c0$chapter-t([0-9]{3})'
    r'$',
  );
  final match = expression.firstMatch(slug);
  return match == null ? null : int.tryParse(match.group(1)!);
}

SelfRuqyahGuideGroup? selfRuqyahGroupBySlug(int chapter, String? slug) {
  for (final group in selfRuqyahGroups) {
    if (group.chapter == chapter && group.slug == slug) return group;
  }
  return null;
}

class SelfRuqyahGuideIndex extends StatelessWidget {
  const SelfRuqyahGuideIndex({
    super.key,
    required this.resources,
    required this.onOpenResource,
    this.chapterNumber,
    this.groupSlug,
  });

  final List<ContentResource> resources;
  final ValueChanged<ContentResource> onOpenResource;
  final int? chapterNumber;
  final String? groupSlug;

  List<ContentResource> _topicsFor(int chapter, SelfRuqyahGuideGroup? group) {
    final selected = resources
        .where((resource) {
          final number = selfRuqyahTopicNumber(resource.slug, chapter);
          return number != null &&
              (group == null ||
                  (number >= group.firstTopic && number <= group.lastTopic));
        })
        .toList(growable: false);
    return selected..sort((a, b) => (a.slug ?? '').compareTo(b.slug ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('এই বিভাগে এখনো উপকরণ নেই')),
      );
    }
    final chapter = chapterNumber;
    if (chapter == null) return _chapters(context);
    if (chapter < 1 || chapter > 4) {
      return const Center(child: Text('অধ্যায়টি পাওয়া যায়নি'));
    }

    final group = groupSlug == null
        ? null
        : selfRuqyahGroupBySlug(chapter, groupSlug);
    if (groupSlug != null && group == null) {
      return const Center(child: Text('বিষয়টি পাওয়া যায়নি'));
    }
    if (group != null) return _topicList(context, chapter, group);
    return _groups(context, chapter);
  }

  Widget _chapters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('অধ্যায়সমূহ', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        for (var chapter = 1; chapter <= 4; chapter++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NavigationCard(
              key: Key('self-guide-chapter-$chapter'),
              icon: Icons.menu_book_outlined,
              title: selfRuqyahChapterLabels[chapter - 1],
              subtitle: selfRuqyahChapterTitles[chapter - 1],
              onTap: () => context.push('$_guidePath/chapter/$chapter'),
            ),
          ),
      ],
    );
  }

  Widget _groups(BuildContext context, int chapter) {
    final chapterGroups = selfRuqyahGroups
        .where((item) => item.chapter == chapter)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          selfRuqyahChapterLabels[chapter - 1],
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 5),
        Text(
          selfRuqyahChapterTitles[chapter - 1],
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        for (final group in chapterGroups)
          if (_topicsFor(chapter, group).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NavigationCard(
                key: Key('self-guide-group-${group.slug}'),
                icon: Icons.library_books_outlined,
                title: group.title,
                subtitle: '${_topicsFor(chapter, group).length}টি বিষয়',
                onTap: () => context.push(
                  '$_guidePath/chapter/$chapter/group/${group.slug}',
                ),
              ),
            ),
      ],
    );
  }

  Widget _topicList(
    BuildContext context,
    int chapter,
    SelfRuqyahGuideGroup group,
  ) {
    final items = _topicsFor(chapter, group);
    if (items.isEmpty) {
      return const Center(child: Text('এই বিষয়ে এখনো পাঠ নেই'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          selfRuqyahChapterLabels[chapter - 1],
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 5),
        Text(group.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: SukunGlassCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: Key('self-guide-topic-${item.slug}'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                title: Text(item.titleBn ?? item.title),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onOpenResource(item),
              ),
            ),
          ),
      ],
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SukunGlassCard(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
