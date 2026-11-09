import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/challenges/domain/forty_day_challenge_content.dart';

void main() {
  test('five day groups have a guide and the opening group has both audios', () {
    expect(challengeStageLinks.length, 5);
    for (final links in challengeStageLinks) {
      expect(links, isNotEmpty);
      expect(links.any((link) => link.kind == ChallengeResourceKind.pdf), isTrue);
    }
    expect(
      challengeStageLinks.first
          .where((link) => link.kind == ChallengeResourceKind.audio)
          .length,
      2,
    );
  });

  test('published resource links are HTTPS and unique', () {
    final all = [
      ...challengeGettingStartedLinks,
      for (final stage in challengeStageLinks) ...stage,
      ...challengeSupportLinks,
    ];
    final urls = <String>{};
    for (final link in all) {
      final uri = Uri.tryParse(link.url);
      expect(uri, isNotNull, reason: link.title);
      expect(uri!.scheme, 'https', reason: link.title);
      expect(uri.host, isNotEmpty, reason: link.title);
      expect(urls.add(link.url), isTrue, reason: link.title);
    }
  });
}
