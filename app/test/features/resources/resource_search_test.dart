import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_search.dart';
import 'package:sukun_life/features/resources/domain/resource_search_documents.dart';

ContentResource _item(
  String id,
  String type,
  String titleBn, {
  String? category,
  String? categoryBn,
}) => ContentResource(
  id: id,
  type: type,
  title: id,
  titleBn: titleBn,
  categorySlug: category,
  categoryNameBn: categoryBn,
  visibility: 'public',
  status: 'published',
);

void main() {
  final catalog = [
    _item(
      'tasbih',
      'dua',
      'ঘুমের আগে তাসবিহ (৩৩, ৩৩ ও ৩৪ বার)',
      category: 'dua-azkar-ma-09',
      categoryBn: 'ঘুমের আগে: ফজিলতের আরও দোয়া',
    ),
    _item('fatemi', 'amal', 'তাসবীহে ফাতেমী'),
    _item(
      'kursi-audio',
      'audio',
      'আয়াতুল কুরসির রুকইয়াহ',
      category: 'ruqyah-lib-topic',
      categoryBn: 'বিষয়ভিত্তিক রুকইয়াহ',
    ),
    _item(
      'kursi-dua',
      'dua',
      'আয়াতুল কুরসি, ১ বার',
      category: 'dua-azkar-ma-01',
      categoryBn: 'হিফাজতের প্রাথমিক দোয়া',
    ),
    _item('pdf', 'pdf', 'বদনজরের রুকইয়াহর আয়াত'),
    _item('zikr', 'dua', 'অন্যান্য সময়ের যিকর'),
  ];
  final documents = [for (final item in catalog) resourceSearchDocument(item)];
  List<String> ids(String query) => [
    for (final item in rankSearch(documents, query)) item.id,
  ];

  test('Bangla vowel signs are kept, so words are not split apart', () {
    expect(normalizeSearchText('তাসবিহ'), isNot(contains(' ')));
    expect(searchTerms('তাসবিহ ফাতেমী'), hasLength(2));
  });

  test('a partial word already matches while typing', () {
    expect(ids('তা'), containsAll(['tasbih', 'fatemi']));
    expect(ids('তাস'), containsAll(['tasbih', 'fatemi']));
    expect(ids('তাস'), isNot(contains('kursi-audio')));
  });

  test('common Bangla spelling variants find the same items', () {
    expect(ids('তাসবীহ'), containsAll(['tasbih', 'fatemi']));
    expect(ids('তাসবিহ'), containsAll(['tasbih', 'fatemi']));
    expect(ids('জিকর'), contains('zikr'));
    expect(ids('কুরসী'), containsAll(['kursi-audio', 'kursi-dua']));
  });

  test('type words list every item of that kind', () {
    expect(ids('অডিও'), ['kursi-audio']);
    expect(ids('পিডিএফ'), ['pdf']);
  });

  test('category and group names find their items', () {
    expect(ids('ঘুমের আগে'), contains('tasbih'));
    expect(ids('বিষয়ভিত্তিক'), ['kursi-audio']);
  });

  test('a title that starts with the query ranks first', () {
    expect(ids('আয়াতুল কুরসি').first, anyOf('kursi-audio', 'kursi-dua'));
    expect(ids('বদনজর').first, 'pdf');
  });

  test('every term must match; empty queries match nothing', () {
    expect(ids('তাসবিহ অডিও'), isEmpty);
    expect(ids('   '), isEmpty);
  });

  test('suggestions offer categories and titles without duplicates', () {
    final ranked = rankSearch(documents, 'রুকইয়াহ');
    final suggestions = buildSearchSuggestions<ContentResource>(
      query: 'রুকইয়াহ',
      rankedMatches: ranked,
      titleOf: resourceDisplayTitle,
      kindOf: (item) => searchKindLabel(item.type),
      categoryOf: resourceCategoryLabel,
    );
    expect(suggestions.first.item, isNull);
    expect(suggestions.first.label, 'বিষয়ভিত্তিক রুকইয়াহ');
    final labels = [for (final s in suggestions) s.label];
    expect(labels.toSet().length, labels.length);
    expect(labels, contains('আয়াতুল কুরসির রুকইয়াহ'));
  });
}
