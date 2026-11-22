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
    // The three RuqyahBD daily masnun amal groups, then the three original
    // groups (hidden while they hold no published dua).
    expect(duaAzkarNavigationGroups.length, 6);
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
      for (final group in duaAzkarNavigationGroups.take(3))
        ...group.categorySlugs,
    ];
    expect(masnun.length, 18);
    expect(masnun.toSet().length, 18);
    expect(masnun.toSet(), {
      for (var i = 1; i <= 18; i++) 'dua-azkar-ma-${'$i'.padLeft(2, '0')}',
    });
    expect(duaAzkarNavigationGroups.first.slug, 'masnun-morning-evening');
  });

  test('groups follow the RuqyahBD masnun amal index', () {
    expect(
      [for (final group in duaAzkarNavigationGroups.take(3)) group.slug],
      ['masnun-morning-evening', 'masnun-sleep', 'masnun-daily'],
    );
    expect(duaAzkarNavigationGroups[2].categorySlugs, [
      'dua-azkar-ma-13',
      'dua-azkar-ma-14',
      'dua-azkar-ma-15',
      'dua-azkar-ma-17',
      'dua-azkar-ma-18',
    ]);
    // The old "special needs" link still resolves to the merged group.
    expect(duaAzkarGroupAliases['masnun-needs'], 'masnun-daily');
    expect(duaAzkarGroupForCategory('dua-azkar-ma-14')?.slug, 'masnun-daily');
  });
}
