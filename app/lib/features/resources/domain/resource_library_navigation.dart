import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:sukun_life/features/resources/domain/ruqyah_audio_topics.dart';

/// One titled run of categories inside a navigation group.
class LibraryNavShelf {
  const LibraryNavShelf({required this.categorySlugs, this.titleBn});

  final String? titleBn;
  final List<String> categorySlugs;
}

/// A folder between a Resources section and its categories, e.g.
/// "দোয়া ও যিকর" → "ঘুমের আগে ও পরে" → "ঘুমের আগে: তিনকুল".
///
/// The public Resources tab and the Admin library picker both read this, so
/// an admin navigates the library exactly the way a patient does.
class LibraryNavGroup {
  const LibraryNavGroup({
    required this.slug,
    required this.titleBn,
    required this.shelves,
  });

  final String slug;
  final String titleBn;
  final List<LibraryNavShelf> shelves;

  List<String> get categorySlugs => [
    for (final shelf in shelves) ...shelf.categorySlugs,
  ];
}

/// Pseudo category for Ruqyah Ayat excerpts and Ruqyah dua articles that
/// carry no CMS category of their own.
const ruqyahAyatNavCategory = 'ruqyah-ayat';

/// Pseudo category for published Ruqyah audio outside the library groups.
const ruqyahUngroupedNavCategory = 'ruqyah-more-audio';

/// Navigation groups of a Resources section, in display order. Sections
/// without groups list their categories directly.
List<LibraryNavGroup> libraryNavGroupsForSection(String sectionSlug) =>
    switch (sectionSlug) {
      'dua-azkar' => [
        for (final group in duaAzkarNavigationGroups)
          LibraryNavGroup(
            slug: group.slug,
            titleBn: group.titleBn,
            shelves: [LibraryNavShelf(categorySlugs: group.categorySlugs)],
          ),
      ],
      'ruqyah' => [
        LibraryNavGroup(
          slug: 'ruqyah-audio',
          titleBn: 'রুকইয়াহ অডিও',
          shelves: [
            for (final shelf in ruqyahAudioShelves)
              LibraryNavShelf(
                titleBn: shelf.titleBn,
                categorySlugs: [for (final topic in shelf.topics) topic.slug],
              ),
            const LibraryNavShelf(
              titleBn: 'আরও অডিও',
              categorySlugs: [ruqyahUngroupedNavCategory],
            ),
          ],
        ),
        const LibraryNavGroup(
          slug: 'ruqyah-ayat',
          titleBn: 'রুকইয়াহ আয়াত',
          shelves: [
            LibraryNavShelf(categorySlugs: [ruqyahAyatNavCategory]),
          ],
        ),
        const LibraryNavGroup(
          slug: 'ruqyah-self-guide',
          titleBn: 'সেলফ-রুকইয়াহ গাইড',
          shelves: [
            LibraryNavShelf(categorySlugs: ['ruqyah-self-guide']),
          ],
        ),
      ],
      _ => const [],
    };

/// Bangla title of a category slug used by a navigation group, if known.
String? libraryNavCategoryTitle(String slug) {
  final dua = duaAzkarCategoryTitle(slug);
  if (dua != null) return dua;
  for (final topic in ruqyahLibraryTopics) {
    if (topic.slug == slug) return topic.titleBn;
  }
  return switch (slug) {
    ruqyahUngroupedNavCategory => ruqyahUngroupedAudioTopic.titleBn,
    ruqyahAyatNavCategory => 'রুকইয়াহ আয়াত ও দোয়া',
    'ruqyah-self-guide' => 'সেলফ-রুকইয়াহ গাইড',
    _ => null,
  };
}

/// Category slug a Ruqyah-section item is filed under for navigation.
String ruqyahNavCategoryFor({
  required String type,
  required String? categorySlug,
  required String? slug,
}) {
  if (type == 'audio') {
    return isRuqyahLibraryCategory(categorySlug)
        ? categorySlug!
        : ruqyahUngroupedNavCategory;
  }
  if (categorySlug == 'ruqyah-self-guide' ||
      type == 'guide' ||
      type == 'amal') {
    return 'ruqyah-self-guide';
  }
  if (type == 'quran' ||
      categorySlug == 'ruqyah-ayat' ||
      (slug?.startsWith('srg2024-qur-') ?? false) ||
      (slug?.startsWith('srg2024-dua-') ?? false)) {
    return ruqyahAyatNavCategory;
  }
  return categorySlug ?? '';
}
