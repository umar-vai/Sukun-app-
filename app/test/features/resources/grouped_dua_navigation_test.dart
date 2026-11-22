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
    // Four daily masnun amal groups, then the three original groups.
    expect(duaAzkarNavigationGroups.length, 7);
    expect(
      duaAzkarNavigationGroups
          .firstWhere((group) => group.slug == 'time-based')
          .categorySlugs,
      containsAll([
        'dua-azkar-morning',
        'dua-azkar-evening',
        'dua-azkar-sleep',
      ]),
    );
  });

  test('daily masnun amal covers its 18 groups in order', () {
    final masnun = [
      for (final group in duaAzkarNavigationGroups.take(4))
        ...group.categorySlugs,
    ];
    expect(masnun.length, 18);
    expect(masnun.toSet().length, 18);
    expect(masnun.toSet(), {
      for (var i = 1; i <= 18; i++) 'dua-azkar-ma-${'$i'.padLeft(2, '0')}',
    });
    expect(duaAzkarNavigationGroups.first.slug, 'masnun-morning-evening');
  });
}
