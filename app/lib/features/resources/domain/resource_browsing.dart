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
  ),
];

/// Display-only grouping for the seven existing approved dua categories.
/// Group names organize navigation, not religious claims or new source text.
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
    categorySlugs: [
      'dua-azkar-masnun',
      'dua-azkar-travel',
    ],
  ),
  DuaAzkarNavigationGroup(
    slug: 'support',
    titleBn: 'সুরক্ষা ও দুশ্চিন্তার দোয়া',
    categorySlugs: [
      'dua-azkar-protection',
      'dua-azkar-distress',
    ],
  ),
];

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
