import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/supabase_resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';

void main() {
  ContentResource item(String type, {String? slug}) => ContentResource(
    id: 'synthetic-$type',
    type: type,
    title: 'Synthetic resource',
    visibility: 'public',
    status: 'published',
    categorySlug: slug,
  );

  test(
    'published source-book dua and amal with no category stay discoverable',
    () {
      expect(
        resourceMatchesCategoryFilter(item('dua'), {'dua', 'azkar'}),
        isTrue,
      );
      expect(
        resourceMatchesCategoryFilter(item('amal'), {'dua', 'azkar'}),
        isTrue,
      );
      expect(
        resourceMatchesCategoryFilter(item('article'), {'dua', 'azkar'}),
        isFalse,
      );
      expect(resourceMatchesCategoryFilter(item('dua'), {'ruqyah'}), isFalse);
      expect(
        resourceMatchesCategoryFilter(item('dua', slug: 'ruqyah'), {'dua'}),
        isFalse,
      );
    },
  );

  test('explicit category prefixes retain their original scope', () {
    expect(
      resourceMatchesCategoryFilter(item('dua', slug: 'dua-morning'), {'dua'}),
      isTrue,
    );
    expect(
      resourceMatchesCategoryFilter(item('audio', slug: 'ruqyah-audio'), {
        'ruqyah',
      }),
      isTrue,
    );
    expect(
      resourceMatchesCategoryFilter(item('audio', slug: 'audio'), {'dua'}),
      isFalse,
    );
    expect(resourceMatchesCategoryFilter(item('dua'), const {}), isTrue);
  });
}
