import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/media/audio_playback_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('playback position store persists and clears resume position', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesPlaybackPositionStore();

    expect(await store.read('audio-1'), isNull);

    await store.write('audio-1', const Duration(seconds: 73));
    expect(await store.read('audio-1'), const Duration(seconds: 73));

    await store.clear('audio-1');
    expect(await store.read('audio-1'), isNull);
  });
}
