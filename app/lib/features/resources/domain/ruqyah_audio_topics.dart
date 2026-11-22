import 'package:sukun_life/features/resources/domain/content_resource.dart';

/// Browsing labels for already-published material, never medical diagnoses.
class RuqyahBrowseTopic {
  const RuqyahBrowseTopic(this.slug, this.titleBn);

  final String slug;
  final String titleBn;
}

const ruqyahAudioTopics = <RuqyahBrowseTopic>[
  RuqyahBrowseTopic('ruqyah-general', 'সাধারণ রুকইয়াহ'),
  RuqyahBrowseTopic('ruqyah-recitation', 'সূরা ও আয়াতের অডিও'),
  RuqyahBrowseTopic('ruqyah-protection', 'সুরক্ষা'),
  RuqyahBrowseTopic('ruqyah-evil-eye', 'বদনজর'),
  RuqyahBrowseTopic('ruqyah-jinn', 'জিন'),
  RuqyahBrowseTopic('ruqyah-sihr', 'সিহর'),
  RuqyahBrowseTopic('ruqyah-wellness', 'শিফা ও সাকিনা'),
  RuqyahBrowseTopic('ruqyah-special', 'বিশেষ রুকইয়াহ'),
  RuqyahBrowseTopic('ruqyah-other', 'অন্যান্য অডিও'),
];

/// Structured audio library groups. Each maps 1:1 to a CMS category, so a
/// Super Admin can move an item between groups from the content editor.
const ruqyahLibraryTopics = <RuqyahBrowseTopic>[
  RuqyahBrowseTopic('ruqyah-lib-topic', 'বিষয়ভিত্তিক রুকইয়াহ'),
  RuqyahBrowseTopic('ruqyah-lib-reciters', 'বিভিন্ন ক্বারির সাধারণ রুকইয়াহ'),
  RuqyahBrowseTopic('ruqyah-lib-other', 'অন্যান্য রুকইয়াহ অডিও'),
  RuqyahBrowseTopic('ruqyah-lib-special', 'বিশেষ আয়াত, সুরা ও দোয়ার অডিও'),
  RuqyahBrowseTopic('ruqyah-lib-hibshi', 'খালিদ আল হিবশীর বিশেষ রুকইয়াহ'),
  RuqyahBrowseTopic('ruqyah-lib-short', 'বিকল্প ও সংক্ষিপ্ত সংস্করণ'),
  RuqyahBrowseTopic('ruqyah-lib-more-reciters', 'আরও কিছু ক্বারির রুকইয়াহ'),
];

/// The audio library as RuqyahBD lays it out (checked 2026-11-23): the
/// main download page (topic, reciters, other) and its second page
/// "আরও কিছু অডিও" (selected ayat, Hibshi, short versions, more reciters).
class RuqyahAudioShelf {
  const RuqyahAudioShelf(this.titleBn, this.topics);

  final String titleBn;
  final List<RuqyahBrowseTopic> topics;
}

final ruqyahAudioShelves = <RuqyahAudioShelf>[
  RuqyahAudioShelf('রুকইয়াহ অডিও', ruqyahLibraryTopics.sublist(0, 3)),
  RuqyahAudioShelf('আরও কিছু অডিও', ruqyahLibraryTopics.sublist(3)),
];

/// Published audio that is not yet placed in a library group.
const ruqyahUngroupedAudioTopic = RuqyahBrowseTopic(
  'ruqyah-more-audio',
  'আরও অডিও',
);

bool isRuqyahLibraryCategory(String? slug) =>
    ruqyahLibraryTopics.any((topic) => topic.slug == slug);

const ruqyahMainTopics = <RuqyahBrowseTopic>[
  RuqyahBrowseTopic('all', 'সব'),
  RuqyahBrowseTopic('ruqyah-audio', 'রুকইয়াহ অডিও'),
  RuqyahBrowseTopic('ruqyah-ayat', 'রুকইয়াহ আয়াত'),
  RuqyahBrowseTopic('ruqyah-self-guide', 'সেলফ-রুকইয়াহ গাইড'),
];

bool _mentions(String title, List<String> terms) => terms.any(title.contains);

/// Navigation-only membership based on explicit title words or the CMS
/// category. This cannot authorize new content: the caller only supplies
/// resources already returned by the RLS-protected published repository.
/// Unclear titles stay in Other; we never infer a patient's condition.
Set<String> ruqyahBrowseTopicMembership(ContentResource resource) {
  final title =
      (resource.titleBn?.trim().isNotEmpty == true
              ? resource.titleBn!
              : resource.title)
          .trim()
          .toLowerCase();
  final original = resource.categorySlug ?? '';

  if (resource.type != 'audio') {
    if (original == 'ruqyah-ayat' || resource.type == 'quran') {
      return {'ruqyah-ayat'};
    }
    if (original == 'ruqyah-self-guide' ||
        resource.type == 'guide' ||
        resource.type == 'amal') {
      return {'ruqyah-self-guide'};
    }
    return {'ruqyah-other'};
  }

  final slugs = <String>{'ruqyah-audio'};
  if (isRuqyahLibraryCategory(original)) {
    slugs.add(original);
  } else {
    slugs.add(ruqyahUngroupedAudioTopic.slug);
  }
  // The imported placeholder title "jo" supplies no useful topic evidence.
  final isUnclearTitle = title.length < 5;

  if (_mentions(title, ['কমন', 'সাধারণ'])) {
    slugs.add('ruqyah-general');
  }
  if (_mentions(title, [
    'সুরা',
    'সূরা',
    'আয়াত',
    'তিনকুল',
    'তিন কুল',
    'আট সুরার',
    'যিলযাল',
  ])) {
    slugs.add('ruqyah-recitation');
  }
  if (_mentions(title, ['তিনকুল', 'তিন কুল', 'আয়াতুল কুরসি']) ||
      original == 'ruqyah-protection') {
    slugs.add('ruqyah-protection');
  }
  if (_mentions(title, ['বদনজর']) || original == 'ruqyah-evil-eye') {
    slugs.add('ruqyah-evil-eye');
  }
  if (_mentions(title, ['জিনের', 'জিন-']) || original == 'ruqyah-jinn') {
    slugs.add('ruqyah-jinn');
  }
  if (_mentions(title, ['সিহর', 'জাদু']) ||
      (original == 'ruqyah-sihr' && !isUnclearTitle)) {
    slugs.add('ruqyah-sihr');
  }
  if (_mentions(title, ['শিফা', 'সাকিনা']) || original == 'ruqyah-wellness') {
    slugs.add('ruqyah-wellness');
  }
  if (_mentions(title, ['খুরুজ', 'জিনা', 'কিতাল', 'তাদমির'])) {
    slugs.add('ruqyah-special');
  }
  if (!slugs.any(_legacyAudioTopicSlugs.contains)) slugs.add('ruqyah-other');
  return slugs;
}

/// One default section per item; thematic filters can still match an item
/// in multiple places (e.g. Ayatul Kursi in recitation and protection).
String ruqyahPrimaryBrowseTopic(ContentResource resource) {
  final matches = ruqyahBrowseTopicMembership(resource);
  for (final preferred in const [
    'ruqyah-evil-eye',
    'ruqyah-jinn',
    'ruqyah-sihr',
    'ruqyah-wellness',
    'ruqyah-recitation',
    'ruqyah-general',
    'ruqyah-special',
    'ruqyah-other',
  ]) {
    if (matches.contains(preferred)) return preferred;
  }
  return resource.type == 'audio' ? 'ruqyah-other' : 'ruqyah-self-guide';
}

final _legacyAudioTopicSlugs = {
  for (final topic in ruqyahAudioTopics)
    if (topic.slug != 'ruqyah-other') topic.slug,
};

List<ContentResource> resourcesForRuqyahTopic(
  List<ContentResource> authorized,
  String slug,
) {
  if (slug == 'all') return authorized;
  final items = authorized
      .where((resource) => ruqyahBrowseTopicMembership(resource).contains(slug))
      .toList(growable: false);
  if (!isRuqyahLibraryCategory(slug)) return items;
  // Library groups keep the order a Super Admin set in the CMS.
  return [...items]..sort(compareResourcesByOrder);
}

/// Stable admin-controlled order: sort order, then title, then ID.
int compareResourcesByOrder(ContentResource a, ContentResource b) {
  final order = a.sortOrder.compareTo(b.sortOrder);
  if (order != 0) return order;
  final title = (a.titleBn ?? a.title).compareTo(b.titleBn ?? b.title);
  return title != 0 ? title : a.id.compareTo(b.id);
}
