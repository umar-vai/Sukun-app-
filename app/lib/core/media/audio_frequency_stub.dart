import 'audio_frequency_types.dart';

/// No native FFT is claimed without a tested platform PCM tap.
AudioFrequencySource createAudioFrequencySource() => _UnavailableFrequency();

class _UnavailableFrequency implements AudioFrequencySource {
  @override
  void attach(Uri? url) {}
  @override
  void sync(Duration position, bool playing, double speed) {}
  @override
  AudioFrequencyFrame sample() =>
      const AudioFrequencyFrame(status: FrequencyStatus.unsupported);
  @override
  void dispose() {}
}
