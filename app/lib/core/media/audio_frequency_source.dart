import 'audio_frequency_types.dart';
import 'audio_frequency_stub.dart'
    if (dart.library.js_interop) 'audio_frequency_web.dart'
    as platform;

export 'audio_frequency_types.dart';

AudioFrequencySource createAudioFrequencySource() =>
    platform.createAudioFrequencySource();

/// Call directly from Play or the visualizer's user-gesture action.
void unlockAudioFrequencyFromGesture() =>
    platform.unlockAudioFrequencyFromGesture();
