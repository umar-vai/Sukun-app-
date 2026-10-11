/// Native/web adapter contract for genuine FFT frequency measurements.
/// Visualizations must not fabricate sound levels when a host blocks analysis.
enum FrequencyStatus {
  idle,
  ready,
  active,
  paused,
  blocked,
  unsupported,
}

class AudioFrequencyFrame {
  const AudioFrequencyFrame({
    required this.status,
    this.bands = const [],
    this.bass = 0,
    this.mid = 0,
    this.treble = 0,
  });

  final FrequencyStatus status;
  final List<double> bands;
  final double bass;
  final double mid;
  final double treble;
  bool get hasSpectrum =>
      status == FrequencyStatus.active && bands.isNotEmpty;
}

abstract interface class AudioFrequencySource {
  void attach(Uri? url);
  void sync(Duration position, bool playing, double speed);
  AudioFrequencyFrame sample();
  void dispose();
}
