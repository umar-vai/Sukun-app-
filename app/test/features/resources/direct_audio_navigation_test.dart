import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/audio_resource_navigation.dart';

ContentResource exampleResource({
  required String type,
  String? mediaSourceType,
  String? mediaUrl,
}) => ContentResource(
  id: 'public-resource-1',
  type: type,
  title: 'রুকইয়াহ অডিও',
  status: 'published',
  visibility: 'public',
  mediaSourceType: mediaSourceType,
  mediaUrl: mediaUrl,
);

void main() {
  test('valid direct audio resource skips the intermediate detail page', () {
    final audio = exampleResource(
      type: 'audio',
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'https://files.ruqyahbd.org/test.mp3',
    );
    expect(isDirectPlayableAudio(audio), isTrue);
  });

  test(
    'valid audio attachment also opens the player for another content type',
    () {
      final audio = exampleResource(
        type: 'guide',
        mediaSourceType: 'direct_audio_url',
        mediaUrl: 'https://files.ruqyahbd.org/test.mp3',
      );
      expect(isDirectPlayableAudio(audio), isTrue);
    },
  );

  test('PDF, invalid or insecure links still use the normal detail page', () {
    expect(
      isDirectPlayableAudio(
        exampleResource(
          type: 'guide',
          mediaSourceType: 'external_pdf',
          mediaUrl: 'https://example.org/file.pdf',
        ),
      ),
      isFalse,
    );
    expect(
      isDirectPlayableAudio(
        exampleResource(
          type: 'audio',
          mediaSourceType: 'direct_audio_url',
          mediaUrl: 'http://example.org/audio.mp3',
        ),
      ),
      isFalse,
    );
    expect(isDirectPlayableAudio(exampleResource(type: 'audio')), isFalse);
  });
}
