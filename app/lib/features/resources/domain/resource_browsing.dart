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
