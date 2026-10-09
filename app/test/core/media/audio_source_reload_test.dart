import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

void main() {
  const original = LinkedResource(
    id: 'audio-1',
    title: 'Ruqyah audio',
    type: 'audio',
    mediaSourceType: 'direct_audio_url',
    mediaUrl: 'https://cdn.example.org/first.mp3',
  );

  test('same audio source can reuse player state', () {
    expect(audioResourceNeedsReload(original, original), isFalse);
    expect(audioResourceNeedsReload(null, original), isTrue);
  });

  test('updated URL of the same resource forces a fresh media load', () {
    const refreshed = LinkedResource(
      id: 'audio-1',
      title: 'Ruqyah audio',
      type: 'audio',
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'https://cdn.example.org/second.mp3',
    );
    expect(audioResourceNeedsReload(original, refreshed), isTrue);
  });

  test('a changed resource ID or media source forces reload', () {
    const next = LinkedResource(
      id: 'audio-2',
      title: 'Another audio',
      type: 'audio',
      mediaSourceType: 'direct_audio_url',
      mediaUrl: 'https://cdn.example.org/first.mp3',
    );
    const changedType = LinkedResource(
      id: 'audio-1',
      title: 'Ruqyah audio',
      type: 'audio',
      mediaSourceType: 'external_web',
      mediaUrl: 'https://cdn.example.org/first.mp3',
    );
    expect(audioResourceNeedsReload(original, next), isTrue);
    expect(audioResourceNeedsReload(original, changedType), isTrue);
  });
}
