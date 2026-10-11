import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/media/audio_frequency_source.dart';

/// Actual Web Audio FFT values, never a play/pause-dependent imitation.
/// Audio playback remains in just_audio. The Web analyzer attempts a separate
/// CORS-enabled, inaudible stream from the same external media host.
/// Unavailable sources remain readable and playable with a clear explanation.
class SukunAudioVisualizer extends StatefulWidget {
  const SukunAudioVisualizer({
    super.key,
    required this.playing,
    required this.position,
    this.audioUrl,
    this.playbackSpeed = 1,
    this.animated = true,
    this.source,
  });

  final bool playing;
  final Duration position;
  final Uri? audioUrl;
  final double playbackSpeed;
  final bool animated;

  /// Injection point for deterministic FFT regression tests.
  final AudioFrequencySource? source;

  @override
  State<SukunAudioVisualizer> createState() => _SukunAudioVisualizerState();
}

class _SukunAudioVisualizerState extends State<SukunAudioVisualizer> {
  late AudioFrequencySource _source;
  Timer? _ticker;
  AudioFrequencyFrame _frame =
      const AudioFrequencyFrame(status: FrequencyStatus.idle);

  bool get _enabled =>
      widget.playing &&
      widget.animated &&
      !MediaQuery.disableAnimationsOf(context) &&
      widget.audioUrl != null;

  @override
  void initState() {
    super.initState();
    _source = widget.source ?? createAudioFrequencySource();
    _source.attach(widget.audioUrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTicker();
  }

  @override
  void didUpdateWidget(covariant SukunAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source && widget.source != null) {
      _source.dispose();
      _source = widget.source!;
      _source.attach(widget.audioUrl);
    } else if (oldWidget.audioUrl != widget.audioUrl) {
      _source.attach(widget.audioUrl);
    }
    _updateTicker();
  }

  void _updateTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (_enabled) {
      // Do not notify listeners during initState/didUpdateWidget build.
      _ticker = Timer.periodic(const Duration(milliseconds: 70), (_) => _tick());
    } else {
      _source.sync(widget.position, false, widget.playbackSpeed);
      _frame = const AudioFrequencyFrame(status: FrequencyStatus.paused);
    }
  }

  void _tick() {
    if (!mounted || !_enabled) return;
    _source.sync(widget.position, true, widget.playbackSpeed);
    final current = _source.sample();
    if (mounted) setState(() => _frame = current);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = _enabled && _frame.hasSpectrum;
    final description = !_enabled
        ? 'লাইভ ফ্রিকোয়েন্সি বন্ধ'
        : switch (_frame.status) {
            FrequencyStatus.active => 'লাইভ Bass · Mid · Treble',
            FrequencyStatus.blocked =>
              'অডিও সার্ভার লাইভ সিগন্যালের অনুমতি দেয়নি',
            FrequencyStatus.unsupported =>
              'এই প্ল্যাটফর্মে লাইভ অ্যানালাইসিস নেই',
            _ => 'অডিও ফ্রিকোয়েন্সির জন্য অপেক্ষা…',
          };
    return Semantics(
      label: description,
      image: true,
      child: Column(
        children: [
          SizedBox(
            height: 106,
            width: double.infinity,
            child: CustomPaint(
              key: const ValueKey('live-audio-frequency-bars'),
              painter: _FrequencyBarsPainter(
                bands: running ? _frame.bands : const [],
                active: running,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            key: const ValueKey('audio-frequency-status'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD1E6F3),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrequencyBarsPainter extends CustomPainter {
  const _FrequencyBarsPainter({required this.bands, required this.active});

  final List<double> bands;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 36;
    const gap = 3.5;
    final barWidth =
        math.max(2, math.min(8, (size.width - (count - 1) * gap) / count))
            .toDouble();
    final width = count * barWidth + (count - 1) * gap;
    final left = (size.width - width) / 2;
    final middle = size.height / 2;

    for (var index = 0; index < count; index++) {
      // The actual FFT energy is sourced from analyser.getByteFrequencyData.
      final energy = active && index < bands.length
          ? bands[index].clamp(0.0, 1.0)
          : 0.0;
      final barHeight = 5 + math.sqrt(energy) * (size.height - 11);
      final tint = Color.lerp(
        SukunColors.sukunBlue,
        const Color(0xFFE8F5FC),
        index / (count - 1) * 0.68,
      )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left + index * (barWidth + gap),
            middle - barHeight / 2,
            barWidth,
            barHeight,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = tint.withValues(alpha: active ? 0.98 : 0.48),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FrequencyBarsPainter other) =>
      active != other.active || !identical(bands, other.bands);
}
