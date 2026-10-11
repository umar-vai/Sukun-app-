import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';

/// Decorative, completely static waveform for the audio player's cover.
///
/// The varied bar pattern is deliberately fixed rather than sourced from the
/// audio stream. This widget creates no timer, player, WebAudio context,
/// network request, storage object, or animation controller.
class SukunStaticWaveform extends StatelessWidget {
  const SukunStaticWaveform({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'অডিও প্লেয়ারের স্থির তরঙ্গচিত্র',
    image: true,
    child: const SizedBox(
      height: 106,
      width: double.infinity,
      child: CustomPaint(
        key: ValueKey('static-audio-waveform'),
        painter: _StaticWavePainter(),
      ),
    ),
  );
}

class _StaticWavePainter extends CustomPainter {
  const _StaticWavePainter();

  /// An intentionally irregular yet balanced composition, not live spectrum.
  static const List<double> _heights = [
    0.34,
    0.48,
    0.61,
    0.82,
    0.57,
    0.92,
    0.69,
    0.44,
    0.76,
    0.97,
    0.64,
    0.41,
    0.78,
    0.54,
    0.88,
    0.59,
    0.43,
    0.72,
    0.98,
    0.67,
    0.50,
    0.82,
    0.63,
    0.37,
    0.74,
    0.51,
    0.91,
    0.66,
    0.45,
    0.79,
    0.56,
    0.35,
    0.62,
    0.86,
    0.49,
    0.29,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final count = _heights.length;
    const gap = 3.5;
    final width = math.max(
      2.0,
      math.min(7.0, (size.width - (count - 1) * gap) / count),
    );
    final totalWidth = count * width + (count - 1) * gap;
    final offsetX = (size.width - totalWidth) / 2;
    final middleY = size.height / 2;

    for (var i = 0; i < count; i++) {
      final barHeight = 8 + _heights[i] * (size.height - 16);
      final tint = Color.lerp(
        SukunColors.sukunBlue,
        const Color(0xFFE8F5FC),
        i / (count - 1) * 0.68,
      )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            offsetX + i * (width + gap),
            middleY - barHeight / 2,
            width,
            barHeight,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = tint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaticWavePainter oldDelegate) => false;
}
