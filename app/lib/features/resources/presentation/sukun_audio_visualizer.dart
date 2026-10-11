import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';

/// A lightweight position-synced ambient waveform for streaming audio.
///
/// This animation responds to play/pause, seek and playback position. It is not
/// an FFT or a representation of the actual audio-frequency spectrum: the
/// current just_audio playback pipeline does not expose decoded PCM samples.
/// True beat analysis requires a separate, permission-safe audio analysis
/// adapter, rather than displaying invented amplitude values as measurements.
class SukunAudioVisualizer extends StatefulWidget {
  const SukunAudioVisualizer({
    super.key,
    required this.playing,
    required this.position,
    this.animated = true,
  });

  final bool playing;
  final Duration position;
  final bool animated;

  @override
  State<SukunAudioVisualizer> createState() => _SukunAudioVisualizerState();
}

class _SukunAudioVisualizerState extends State<SukunAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );

  @override
  void initState() {
    super.initState();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant SukunAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing ||
        oldWidget.animated != widget.animated) {
      _syncMotion();
    }
  }

  void _syncMotion() {
    if (widget.playing && widget.animated) {
      _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animate = widget.animated && !reduceMotion && widget.playing;
    return Semantics(
      label: animate
          ? 'অডিও চলছে, প্লেব্যাক অ্যানিমেশন চলছে'
          : 'অডিও প্লেব্যাক ভিজ্যুয়ালাইজার স্থির আছে',
      image: true,
      child: SizedBox(
        height: 96,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, child) => CustomPaint(
            painter: _AudioBarsPainter(
              positionSeconds: widget.position.inMilliseconds / 1000,
              motion: animate ? _motion.value : 0,
              active: animate,
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioBarsPainter extends CustomPainter {
  const _AudioBarsPainter({
    required this.positionSeconds,
    required this.motion,
    required this.active,
  });

  final double positionSeconds;
  final double motion;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 43;
    const gap = 4.1;
    final barWidth = math.max(
      2.0,
      math.min(6.0, (size.width - 42 * gap) / count),
    );
    final totalWidth = count * barWidth + (count - 1) * gap;
    final left = (size.width - totalWidth) / 2;
    final middleY = size.height / 2;
    final phase = positionSeconds * 2.6 + motion * math.pi * 2;
    for (var index = 0; index < count; index++) {
      final normalized = (index - (count - 1) / 2).abs() / (count / 2);
      final dome = 0.3 + 0.7 * (1 - normalized * normalized);
      final pattern =
          0.5 +
          0.25 * math.sin(index * 0.63 + (active ? phase : 0)) +
          0.2 * math.sin(index * 1.39 - (active ? phase * 0.75 : 0));
      final height = math.max(
        5.0,
        math.min(size.height - 6, 8 + dome * 78 * pattern),
      );
      final tint = Color.lerp(
        SukunColors.sukunBlue,
        const Color(0xFFE8F5FC),
        (index / count) * 0.7,
      )!;
      final paint = Paint()
        ..color = tint.withValues(alpha: active ? 0.95 : 0.65);
      final x = left + index * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, middleY - height / 2, barWidth, height),
          const Radius.circular(5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AudioBarsPainter oldDelegate) =>
      oldDelegate.motion != motion ||
      oldDelegate.positionSeconds != positionSeconds ||
      oldDelegate.active != active;
}
