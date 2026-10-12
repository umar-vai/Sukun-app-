import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/resource_matcher.dart';

void main() {
  group('source-backed resource suggestions', () {
    const publicResource = ContentResourceOption(
      id: 'approved-bangla',
      title: 'Ayatul Kursi',
      titleBn: 'আয়াতুল কুরসি',
      type: 'dua',
      visibility: 'public',
      status: 'published',
    );

    test('Bengali ya spellings match one approved resource consistently', () {
      final first = matchResources('আয়াতুল কুরসি', [publicResource]);
      final second = matchResources('আয়াতুল কুরসি', [publicResource]);

      expect(first, hasLength(1));
      expect(second, hasLength(1));
      expect(first.single.resource.id, 'approved-bangla');
      expect(second.single.resource.id, 'approved-bangla');
    });

    test(
      'Bengali vowel marks are preserved; unrelated titles are not merged',
      () {
        const resource = ContentResourceOption(
          id: 'other',
          title: 'দয়া',
          type: 'article',
          visibility: 'public',
          status: 'published',
        );
        expect(matchResources('দোয়া', [resource]), isEmpty);
      },
    );

    test('Arabic vowelization does not prevent matching catalog titles', () {
      const resource = ContentResourceOption(
        id: 'arabic-title',
        title: 'سورة الفاتحة',
        type: 'audio',
        visibility: 'patient_only',
        status: 'published',
      );
      final suggestions = matchResources('سُورَةُ الْفَاتِحَةِ', [resource]);
      expect(suggestions, hasLength(1));
      expect(suggestions.single.resource.id, 'arabic-title');
    });

    test('draft and staff-only items never appear as patient suggestions', () {
      const candidates = [
        ContentResourceOption(
          id: 'draft',
          title: 'Ayatul Kursi',
          type: 'dua',
          visibility: 'public',
          status: 'draft',
        ),
        ContentResourceOption(
          id: 'staff',
          title: 'Ayatul Kursi',
          type: 'dua',
          visibility: 'staff_only',
          status: 'published',
        ),
        publicResource,
      ];
      final suggestions = matchResources('Ayatul Kursi', candidates);
      expect(suggestions.map((match) => match.resource.id), [
        'approved-bangla',
      ]);
    });

    test('missing AI match query never invents a linked resource', () {
      expect(matchResources('', [publicResource]), isEmpty);
      expect(matchResources(null, [publicResource]), isEmpty);
    });
  });
}
