import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/ruqyah_audio_topics.dart';

void main() {
  ContentResource audio(String id, String title, {String? category}) =>
      ContentResource(
        id: id,
        type: 'audio',
        title: title,
        categorySlug: category ?? 'ruqyah-audio',
        status: 'published',
        visibility: 'public',
      );

  test(
    'source-named topics assign every published sample to a safe section',
    () {
      final items = [
        audio('common', 'বাংলা অনুবাদসহ কমন রুকইয়াহ'),
        audio('general', 'শায়খ লুহাইদানের সাধারণ রুকইয়াহ'),
        audio('bakara', 'সুরা বাকারা — শায়খ সুদাইস'),
        audio('kursi', 'আয়াতুল কুরসির রুকইয়াহ'),
        audio('qul', 'তিনকুলের রুকইয়াহ'),
        audio('eye', 'বদনজরের রুকইয়াহ'),
        audio('jinn', 'জিনের আছরের রুকইয়াহ'),
        audio('sihr', 'সিহর হিবশি (জাদু বিষয়ক)'),
        audio('wellness', 'শিফা ও সাকিনা রুকইয়াহ'),
        audio('special', 'রুকইয়াহ জিনা'),
        audio('misc', 'শায়খ লুহাইদান'),
        audio('unknown', 'jo', category: 'ruqyah-sihr'),
      ];
      final expectedTopics = ruqyahAudioTopics.map((t) => t.slug).toSet();
      expect(
        items.every(
          (item) => expectedTopics.contains(ruqyahPrimaryBrowseTopic(item)),
        ),
        isTrue,
      );
      expect(items.map((i) => i.id).toSet().length, items.length);
      expect(
        resourcesForRuqyahTopic(items, 'ruqyah-audio').length,
        items.length,
      );
      expect(
        resourcesForRuqyahTopic(items, 'ruqyah-recitation').map((r) => r.id),
        containsAll(['bakara', 'kursi', 'qul']),
      );
      expect(
        resourcesForRuqyahTopic(items, 'ruqyah-protection').map((r) => r.id),
        containsAll(['kursi', 'qul']),
      );
      expect(
        resourcesForRuqyahTopic(items, 'ruqyah-evil-eye').single.id,
        'eye',
      );
      expect(resourcesForRuqyahTopic(items, 'ruqyah-jinn').single.id, 'jinn');
      expect(
        resourcesForRuqyahTopic(items, 'ruqyah-sihr').map((r) => r.id),
        contains('sihr'),
      );
      expect(
        resourcesForRuqyahTopic(items, 'ruqyah-sihr').map((r) => r.id),
        isNot(contains('unknown')),
      );
      expect(
        resourcesForRuqyahTopic(items, 'ruqyah-other').map((r) => r.id),
        containsAll(['misc', 'unknown']),
      );
      expect(ruqyahPrimaryBrowseTopic(items[9]), 'ruqyah-special');
      expect(
        ruqyahBrowseTopicMembership(items[9]),
        isNot(contains('ruqyah-jinn')),
      );
    },
  );

  test('non-audio guides and canonical ayat do not turn into audio cards', () {
    const guide = ContentResource(
      id: 'guide',
      type: 'guide',
      title: 'Self Guide',
      categorySlug: 'ruqyah-self-guide',
      visibility: 'public',
      status: 'published',
    );
    const ayat = ContentResource(
      id: 'ayat',
      type: 'quran',
      title: 'Canonical ayat',
      categorySlug: 'ruqyah-ayat',
      visibility: 'public',
      status: 'published',
    );
    expect(ruqyahBrowseTopicMembership(guide), {'ruqyah-self-guide'});
    expect(ruqyahBrowseTopicMembership(ayat), {'ruqyah-ayat'});
    expect(resourcesForRuqyahTopic([guide, ayat], 'ruqyah-audio'), isEmpty);
  });

  test('each default group is unique despite overlapping category filters', () {
    final items = [
      audio('a', 'আয়াতুল কুরসির রুকইয়াহ'),
      audio('b', 'তিনকুলের রুকইয়াহ'),
      audio('c', 'বদনজরের রুকইয়াহ'),
    ];
    final counted = <String, int>{};
    for (final item in items) {
      final primary = ruqyahPrimaryBrowseTopic(item);
      counted.update(primary, (n) => n + 1, ifAbsent: () => 1);
    }
    expect(counted.values.fold<int>(0, (sum, n) => sum + n), items.length);
    expect(resourcesForRuqyahTopic(items, 'ruqyah-protection').length, 2);
  });
}
