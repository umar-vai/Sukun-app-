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

    test('English Al-Baqarah finds published Bengali Surah audio but never auto-links a recitation', () {
      const approvedRecording = ContentResourceOption(
        id: 'baqarah-audio',
        title: 'সুরা বাকারা — শায়খ সুদাইস',
        type: 'audio',
        visibility: 'public',
        status: 'published',
        mediaSourceType: 'direct_audio_url',
        mediaUrl: 'https://example.org/baqarah.mp3',
      );
      const unpublished = ContentResourceOption(
        id: 'draft-verse',
        title: 'Surah Al-Baqarah',
        type: 'quran',
        visibility: 'public',
        status: 'review',
        verificationStatus: 'pending',
      );
      final matches = matchResources(
        'Surah Al-Baqarah Completion',
        [approvedRecording, unpublished],
      );
      expect(matches.map((m) => m.resource.id), ['baqarah-audio']);
      expect(exactReviewResource(matches, actionType: 'recitation'), isNull);
      expect(exactReviewResource(matches, actionType: 'listening'), isNull);
      expect(
        resourceMatchesSearch(approvedRecording, 'Surah Al Baqarah'),
        isTrue,
      );
      expect(resourceMatchesSearch(approvedRecording, 'সূরা বাকারা'), isTrue);
    });

    test('bedtime reference cannot invent a complete approved Masnun pack', () {
      const individualAmal = ContentResourceOption(
        id: 'wudu-before-sleep',
        title: 'অজু করে ঘুমানো এবং ডান কাত হওয়া',
        type: 'amal',
        status: 'published',
        visibility: 'public',
      );
      expect(resourceMatchesSearch(individualAmal, 'sleep'), isTrue);
      expect(matchResources('Bedtime Masnun Routine', [individualAmal]), isEmpty);
    });

    test('missing AI match query never invents a linked resource', () {
      expect(matchResources('', [publicResource]), isEmpty);
      expect(matchResources(null, [publicResource]), isEmpty);
    });

    test(
      'numeric ayat citation matches only exact verified Quran references',
      () {
        const approved = ContentResourceOption(
          id: 'quran-2-255',
          title: 'Ayatul Kursi',
          type: 'quran',
          visibility: 'public',
          status: 'published',
          verificationStatus: 'verified',
          surahNumber: 2,
          ayahNumber: 255,
        );
        const wrongAyah = ContentResourceOption(
          id: 'quran-2-256',
          title: 'Similar Ayat',
          type: 'quran',
          visibility: 'public',
          status: 'published',
          verificationStatus: 'verified',
          surahNumber: 2,
          ayahNumber: 256,
        );
        const unverified = ContentResourceOption(
          id: 'unverified',
          title: 'Other duplicate',
          type: 'quran',
          visibility: 'public',
          status: 'published',
          surahNumber: 2,
          ayahNumber: 255,
        );
        final library = [wrongAyah, unverified, approved];
        expect(
          matchResources('2:255', library).single.resource.id,
          approved.id,
        );
        expect(
          matchResources('সূরা ২ আয়াত ২৫৫', library).single.resource.id,
          approved.id,
        );
        expect(
          matchResources('Surah 2 Ayah 255', library).single.resource.id,
          approved.id,
        );
        expect(matchResources('2:257', library), isEmpty);
        expect(matchResources('2:999', library), isEmpty);
      },
    );

    test('exact range and listening media are never guessed from a title', () {
      const single = ContentResourceOption(
        id: 'quran-single',
        title: 'Ruqyah Audio',
        type: 'quran',
        visibility: 'public',
        status: 'published',
        verificationStatus: 'verified',
        surahNumber: 2,
        ayahNumber: 255,
      );
      const verifiedRange = ContentResourceOption(
        id: 'quran-range',
        title: 'Approved Quran range',
        type: 'quran',
        visibility: 'public',
        status: 'published',
        verificationStatus: 'verified',
        surahNumber: 2,
        ayahNumber: 255,
        ayahEndNumber: 257,
      );
      const untrustedAudio = ContentResourceOption(
        id: 'audio-without-url',
        title: 'Ayat recording',
        type: 'audio',
        visibility: 'public',
        status: 'published',
        surahNumber: 2,
        ayahNumber: 255,
        mediaSourceType: 'direct_audio_url',
      );
      expect(
        matchResources('2:255-257', [
          single,
          verifiedRange,
          untrustedAudio,
        ]).single.resource.id,
        'quran-range',
      );
      expect(
        matchResources('2:255', [untrustedAudio, single]).single.resource.id,
        'quran-single',
      );
      expect(matchResources('2:255-256', [single]), isEmpty);
    });
  });
}
