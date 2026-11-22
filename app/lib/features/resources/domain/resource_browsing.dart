import 'package:sukun_life/features/resources/domain/content_resource.dart';

class QuranSurahSummary {
  const QuranSurahSummary({
    required this.surahNumber,
    required this.name,
    required this.ayahCount,
    this.nameBn,
  });

  final int surahNumber;
  final String name;
  final String? nameBn;
  final int ayahCount;
}

class ResourceTopic {
  const ResourceTopic({
    required this.id,
    required this.slug,
    required this.name,
    required this.resourceCount,
    this.nameBn,
  });

  final String id;
  final String slug;
  final String name;
  final String? nameBn;
  final int resourceCount;
}

class ContentCollection {
  const ContentCollection({
    required this.id,
    required this.type,
    required this.title,
    required this.slug,
    required this.visibility,
    required this.status,
    this.titleBn,
    this.summary,
  });

  factory ContentCollection.fromJson(Map<String, dynamic> json) =>
      ContentCollection(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        titleBn: json['title_bn'] as String?,
        slug: json['slug'] as String,
        summary: json['summary'] as String?,
        visibility: json['visibility'] as String,
        status: json['status'] as String,
      );

  final String id;
  final String type;
  final String title;
  final String? titleBn;
  final String slug;
  final String? summary;
  final String visibility;
  final String status;
}

class ContentCollectionDetails {
  const ContentCollectionDetails({
    required this.collection,
    required this.items,
  });

  final ContentCollection collection;
  final List<ContentResource> items;
}

class ResourceTaxonomyEntry {
  const ResourceTaxonomyEntry({
    required this.slug,
    required this.title,
    required this.titleBn,
  });

  final String slug;
  final String title;
  final String titleBn;
}

const duaAzkarTaxonomy = <ResourceTaxonomyEntry>[
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-morning',
    title: 'Morning Azkar',
    titleBn: 'সকালের আযকার',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-evening',
    title: 'Evening Azkar',
    titleBn: 'সন্ধ্যার আযকার',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-masnun',
    title: 'Masnun Dua',
    titleBn: 'মাসনূন দুআ',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-sleep',
    title: 'Sleep',
    titleBn: 'ঘুম',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-travel',
    title: 'Travel',
    titleBn: 'সফর',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-protection',
    title: 'Protection',
    titleBn: 'সুরক্ষা',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-distress',
    title: 'Distress',
    titleBn: 'দুশ্চিন্তা ও কষ্ট',
  ), // Daily masnun amal: 18 groups.
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-01',
    title: 'হিফাজতের প্রাথমিক দোয়া',
    titleBn: 'হিফাজতের প্রাথমিক দোয়া',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-02',
    title: 'হিফাজতের প্রাথমিক আয়াত (তিনকুল)',
    titleBn: 'হিফাজতের প্রাথমিক আয়াত (তিনকুল)',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-03',
    title: 'উপকারী আরও কিছু আয়াত',
    titleBn: 'উপকারী আরও কিছু আয়াত',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-04',
    title: 'হিফাজত ও ফজিলতের আরও দোয়া',
    titleBn: 'হিফাজত ও ফজিলতের আরও দোয়া',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-05',
    title: 'সকাল-সন্ধ্যার আরও কিছু দোয়া',
    titleBn: 'সকাল-সন্ধ্যার আরও কিছু দোয়া',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-06',
    title: 'ফজিলতপূর্ণ আরও কিছু দোয়া',
    titleBn: 'ফজিলতপূর্ণ আরও কিছু দোয়া',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-07',
    title: 'ঘুমের আগে: প্রাথমিক দোয়া ও আয়াত',
    titleBn: 'ঘুমের আগে: প্রাথমিক দোয়া ও আয়াত',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-08',
    title: 'ঘুমের আগে: তিনকুল',
    titleBn: 'ঘুমের আগে: তিনকুল',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-09',
    title: 'ঘুমের আগে: ফজিলতের আরও দোয়া',
    titleBn: 'ঘুমের আগে: ফজিলতের আরও দোয়া',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-10',
    title: 'ঘুমের মাঝে সমস্যা হলে',
    titleBn: 'ঘুমের মাঝে সমস্যা হলে',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-11',
    title: 'ঘুম থেকে জেগে: প্রাথমিক দোয়া',
    titleBn: 'ঘুম থেকে জেগে: প্রাথমিক দোয়া',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-12',
    title: 'ঘুম থেকে জেগে: আরও কিছু আয়াত',
    titleBn: 'ঘুম থেকে জেগে: আরও কিছু আয়াত',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-13',
    title: 'অন্যান্য সময়ের যিকর',
    titleBn: 'অন্যান্য সময়ের যিকর',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-14',
    title: 'শত্রুর ক্ষতির আশংকা করলে',
    titleBn: 'শত্রুর ক্ষতির আশংকা করলে',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-15',
    title: 'বিপদে বা পেরেশানির সময়',
    titleBn: 'বিপদে বা পেরেশানির সময়',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-16',
    title: 'ফজিলতপূর্ণ আরও কিছু আয়াত',
    titleBn: 'ফজিলতপূর্ণ আরও কিছু আয়াত',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-17',
    title: 'দোয়া কবুলের দোয়া',
    titleBn: 'দোয়া কবুলের দোয়া',
  ),
  ResourceTaxonomyEntry(
    slug: 'dua-azkar-ma-18',
    title: 'দাজ্জালের ক্ষতি থেকে বাঁচতে',
    titleBn: 'দাজ্জালের ক্ষতি থেকে বাঁচতে',
  ),
];

/// Display-only grouping of dua categories. Group names organize navigation,
/// not religious claims or new source text.
///
/// The first three groups follow the RuqyahBD daily masnun amal index
/// (checked 2026-11-23): "সকাল-সন্ধ্যায়", "ঘুমের আগে ও পরে" and
/// "অন্যান্য সময়ের যিকর", in the same order with the same sub-sections.
/// The last three hold older categories; a group with no published dua is
/// never shown, so they stay hidden unless a Super Admin publishes into them.
class DuaAzkarNavigationGroup {
  const DuaAzkarNavigationGroup({
    required this.slug,
    required this.titleBn,
    required this.categorySlugs,
  });

  final String slug;
  final String titleBn;
  final List<String> categorySlugs;
}

const duaAzkarNavigationGroups = <DuaAzkarNavigationGroup>[
  DuaAzkarNavigationGroup(
    slug: 'masnun-morning-evening',
    titleBn: 'সকাল-সন্ধ্যার আমল',
    categorySlugs: [
      'dua-azkar-ma-01',
      'dua-azkar-ma-02',
      'dua-azkar-ma-03',
      'dua-azkar-ma-04',
      'dua-azkar-ma-05',
      'dua-azkar-ma-06',
      'dua-azkar-ma-16',
    ],
  ),
  DuaAzkarNavigationGroup(
    slug: 'masnun-sleep',
    titleBn: 'ঘুমের আগে ও পরে',
    categorySlugs: [
      'dua-azkar-ma-07',
      'dua-azkar-ma-08',
      'dua-azkar-ma-09',
      'dua-azkar-ma-10',
      'dua-azkar-ma-11',
      'dua-azkar-ma-12',
    ],
  ),
  DuaAzkarNavigationGroup(
    slug: 'masnun-daily',
    titleBn: 'অন্যান্য সময়ের যিকর',
    categorySlugs: [
      'dua-azkar-ma-13',
      'dua-azkar-ma-14',
      'dua-azkar-ma-15',
      'dua-azkar-ma-17',
      'dua-azkar-ma-18',
    ],
  ),
  DuaAzkarNavigationGroup(
    slug: 'time-based',
    titleBn: 'সময়ভিত্তিক আমল',
    categorySlugs: [
      'dua-azkar-morning',
      'dua-azkar-evening',
      'dua-azkar-sleep',
    ],
  ),
  DuaAzkarNavigationGroup(
    slug: 'everyday',
    titleBn: 'দৈনন্দিন মাসনূন দোয়া',
    categorySlugs: ['dua-azkar-masnun', 'dua-azkar-travel'],
  ),
  DuaAzkarNavigationGroup(
    slug: 'support',
    titleBn: 'সুরক্ষা ও দুশ্চিন্তার দোয়া',
    categorySlugs: ['dua-azkar-protection', 'dua-azkar-distress'],
  ),
];

/// Older group links that were merged into another group.
const duaAzkarGroupAliases = <String, String>{'masnun-needs': 'masnun-daily'};

/// The navigation group a dua category belongs to, if any.
DuaAzkarNavigationGroup? duaAzkarGroupForCategory(String? categorySlug) {
  if (categorySlug == null) return null;
  for (final group in duaAzkarNavigationGroups) {
    if (group.categorySlugs.contains(categorySlug)) return group;
  }
  return null;
}

/// Bangla name of a dua category slug, if it is a known category.
String? duaAzkarCategoryTitle(String? categorySlug) {
  for (final entry in duaAzkarTaxonomy) {
    if (entry.slug == categorySlug) return entry.titleBn;
  }
  return null;
}

const ruqyahTaxonomy = <ResourceTaxonomyEntry>[
  ResourceTaxonomyEntry(
    slug: 'ruqyah-ayat',
    title: 'Ruqyah Ayat',
    titleBn: 'রুকইয়াহ আয়াত',
  ),
  ResourceTaxonomyEntry(
    slug: 'ruqyah-audio',
    title: 'Ruqyah Audio',
    titleBn: 'রুকইয়াহ অডিও',
  ),
  ResourceTaxonomyEntry(
    slug: 'ruqyah-self-guide',
    title: 'Self-Ruqyah Guide',
    titleBn: 'সেলফ-রুকইয়াহ গাইড',
  ),
  ResourceTaxonomyEntry(
    slug: 'ruqyah-protection',
    title: 'Protection',
    titleBn: 'সুরক্ষা',
  ),
  ResourceTaxonomyEntry(
    slug: 'ruqyah-evil-eye',
    title: 'Evil Eye',
    titleBn: 'বদনজর',
  ),
  ResourceTaxonomyEntry(slug: 'ruqyah-jinn', title: 'Jinn', titleBn: 'জিন'),
  ResourceTaxonomyEntry(slug: 'ruqyah-sihr', title: 'Sihr', titleBn: 'সিহর'),
  ResourceTaxonomyEntry(
    slug: 'ruqyah-wellness',
    title: 'Wellness',
    titleBn: 'সুস্থতা',
  ),
];

/// Navigation categories observed in RuqyahBD's ayat index (2026-10-12).
/// This is an editorial navigation blueprint, NOT imported canonical ayat.
class RuqyahAyatIndexEntry {
  const RuqyahAyatIndexEntry({
    required this.slug,
    required this.titleBn,
    this.isDua = false,
  });

  final String slug;
  final String titleBn;
  final bool isDua;
}

const ruqyahAyatIndex = <RuqyahAyatIndexEntry>[
  RuqyahAyatIndexEntry(slug: 'basic-ruqyah', titleBn: 'বেসিক রুকইয়াহ'),
  RuqyahAyatIndexEntry(slug: 'ruqyah-ayat', titleBn: 'রুকইয়াহ আয়াত'),
  RuqyahAyatIndexEntry(
    slug: 'ruqyah-dua',
    titleBn: 'রুকইয়াহ দোয়া',
    isDua: true,
  ),
  RuqyahAyatIndexEntry(slug: 'evil-eye-ayat', titleBn: 'বদনজরের আয়াত'),
  RuqyahAyatIndexEntry(slug: 'sihr-ayat', titleBn: 'সিহরের আয়াত'),
  RuqyahAyatIndexEntry(slug: 'ayat-shifa', titleBn: 'আয়াতুশ শিফা'),
  RuqyahAyatIndexEntry(slug: 'ayat-harq', titleBn: 'আয়াতুল হারক'),
  RuqyahAyatIndexEntry(slug: 'ayat-sakinah', titleBn: 'আয়াতুল সাকিনাহ'),
];
