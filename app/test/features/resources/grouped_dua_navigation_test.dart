import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';

void main() {
  test('all existing approved dua categories appear exactly once', () {
    final displayed = [
      for (final group in duaAzkarNavigationGroups) ...group.categorySlugs,
    ];
    final canonical = [for (final entry in duaAzkarTaxonomy) entry.slug];
    expect(displayed.toSet(), canonical.toSet());
    expect(displayed.length, canonical.length);
  });

  test('group headings remain navigation-only and do not add content', () {
    expect(duaAzkarNavigationGroups.length, 3);
    expect(
      duaAzkarNavigationGroups.first.categorySlugs,
      containsAll([
        'dua-azkar-morning',
        'dua-azkar-evening',
        'dua-azkar-sleep',
      ]),
    );
  });
}
