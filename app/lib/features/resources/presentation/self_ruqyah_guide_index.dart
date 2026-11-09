import 'package:flutter/material.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

/// Four-chapter navigation for published, RLS-authorized self-ruqyah topics.
/// Copyright/provenance fields remain in the CMS, not the reader's content.
class SelfRuqyahGuideIndex extends StatefulWidget {
  const SelfRuqyahGuideIndex({
    super.key,
    required this.resources,
    required this.onOpenResource,
  });

  final List<ContentResource> resources;
  final ValueChanged<ContentResource> onOpenResource;

  @override
  State<SelfRuqyahGuideIndex> createState() => _SelfRuqyahGuideIndexState();
}

class _SelfRuqyahGuideIndexState extends State<SelfRuqyahGuideIndex> {
  final _search = TextEditingController();
  static final _topicSlug = RegExp(r'^srg2024-c0([1-4])-t([0-9]{3})$');
  static const _chapterTitles = <String>[
    'প্রাথমিক আলোচনা',
    'প্যারানরমাল সমস্যা',
    'সেলফ রুকইয়াহ গাইড',
    'রুকইয়াহ পদ্ধতি',
  ];
  static const _chapterLabels = <String>[
    'প্রথম অধ্যায়',
    'দ্বিতীয় অধ্যায়',
    'তৃতীয় অধ্যায়',
    'চতুর্থ অধ্যায়',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terms = _search.text.trim().toLowerCase();
    final topics = widget.resources.where((item) {
      if (_topicSlug.firstMatch(item.slug ?? '') == null) return false;
      if (terms.isEmpty) return true;
      return (item.titleBn ?? item.title).toLowerCase().contains(terms);
    }).toList()..sort((a, b) => (a.slug ?? '').compareTo(b.slug ?? ''));

    final byChapter = <int, List<ContentResource>>{
      for (var chapter = 1; chapter <= 4; chapter++) chapter: [],
    };
    for (final topic in topics) {
      final match = _topicSlug.firstMatch(topic.slug!);
      byChapter[int.parse(match!.group(1)!)]!.add(topic);
    }

    if (widget.resources.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('এই বিভাগে এখনো উপকরণ নেই'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'বিষয় খুঁজুন',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: terms.isEmpty
                ? null
                : IconButton(
                    tooltip: 'অনুসন্ধান মুছুন',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(_search.clear),
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 18),
        if (topics.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text('এই নামে কোনো বিষয় পাওয়া যায়নি।'),
          ),
        for (var chapter = 1; chapter <= 4; chapter++)
          if (byChapter[chapter]!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  key: PageStorageKey('self-ruqyah-chapter-$chapter'),
                  initiallyExpanded: terms.isNotEmpty || chapter == 1,
                  title: Text(
                    _chapterLabels[chapter - 1],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(_chapterTitles[chapter - 1]),
                  trailing: Text('${byChapter[chapter]!.length} বিষয়'),
                  children: [
                    for (final topic in byChapter[chapter]!)
                      ListTile(
                        key: Key('self-ruqyah-topic-${topic.slug}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 3,
                        ),
                        title: Text(topic.titleBn ?? topic.title),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 21,
                        ),
                        onTap: () => widget.onOpenResource(topic),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
