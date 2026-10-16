import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A self-contained four-color Google "G" mark; no remote image or SDK needed.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      key: const Key('google-brand-mark'),
      painter: const _GoogleMarkPainter(),
    ),
  );
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    const center = Offset(12, 12);
    final ring = Rect.fromCircle(center: center, radius: 8.9);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.butt;
    void segment(Color color, double start, double sweep) {
      paint.color = color;
      canvas.drawArc(
        ring,
        start * math.pi / 180,
        sweep * math.pi / 180,
        false,
        paint,
      );
    }

    segment(const Color(0xFF4285F4), -8, 77);
    segment(const Color(0xFF34A853), 69, 65);
    segment(const Color(0xFFFBBC05), 134, 64);
    segment(const Color(0xFFEA4335), 198, 118);
    canvas.drawRect(
      const Rect.fromLTWH(11.7, 10.2, 10.1, 4.3),
      Paint()..color = const Color(0xFF4285F4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}

class GoogleOAuthButton extends StatelessWidget {
  const GoogleOAuthButton({
    super.key,
    required this.onPressed,
    required this.starting,
    required this.label,
  });

  final VoidCallback? onPressed;
  final bool starting;
  final String label;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: starting
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const GoogleMark(),
    label: Text(label),
  );
}
