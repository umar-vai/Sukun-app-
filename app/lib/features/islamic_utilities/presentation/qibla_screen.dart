import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/domain/compass_reading.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  late Future<PrayerUtilitySettings> _settings;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(utilityPreferencesStoreProvider).load();
  }

  Future<void> _configure() async {
    final saved = await context.push<bool>('/prayer-times/settings');
    if (saved == true && mounted) {
      setState(() {
        _settings = ref.read(utilityPreferencesStoreProvider).load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qibla direction')),
      body: FutureBuilder<PrayerUtilitySettings>(
        future: _settings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Preparing Qibla direction');
          }
          if (snapshot.hasError) {
            return AppErrorState(message: snapshot.error.toString());
          }
          final settings = snapshot.data!;
          if (!settings.isComplete) {
            return _QiblaSetupRequired(onConfigure: _configure);
          }
          final schedule = ref
              .read(prayerCalculationServiceProvider)
              .calculate(settings: settings, now: DateTime.now());
          return StreamBuilder<CompassReading>(
            stream: ref.read(compassGatewayProvider).readings(),
            initialData: const CompassReading(
              heading: null,
              calibrationState: CompassCalibrationState.unavailable,
            ),
            builder: (context, compassSnapshot) => _QiblaView(
              locationName: settings.location!.name,
              bearing: schedule.qiblaBearing,
              reading: compassSnapshot.data!,
            ),
          );
        },
      ),
    );
  }
}

class _QiblaSetupRequired extends StatelessWidget {
  const _QiblaSetupRequired({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location needed',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose your location in Prayer settings to calculate the Qibla bearing.',
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onConfigure,
                  child: const Text('Open prayer settings'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QiblaView extends StatelessWidget {
  const _QiblaView({
    required this.locationName,
    required this.bearing,
    required this.reading,
  });

  final String locationName;
  final double bearing;
  final CompassReading reading;

  @override
  Widget build(BuildContext context) {
    final relative = reading.relativeQibla(bearing);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text(
          locationName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        Center(
          child: Semantics(
            label: 'Qibla bearing ${bearing.round()} degrees from north',
            child: SizedBox.square(
              dimension: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(280),
                    painter: const _CompassDialPainter(),
                  ),
                  Transform.rotate(
                    angle: relative * math.pi / 180,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.navigation,
                          size: 96,
                          color: SukunColors.sukunBlue,
                        ),
                        SizedBox(height: 64),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    radius: 31,
                    backgroundColor: SukunColors.nightNavy,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.mosque_outlined, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '${bearing.toStringAsFixed(1)}° from North',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (reading.heading != null) ...[
          const SizedBox(height: 5),
          Text(
            'Phone heading ${reading.heading!.round()}°',
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 20),
        _CalibrationCard(reading: reading),
        const SizedBox(height: 12),
        const Card(
          color: SukunColors.mist,
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'Hold the phone flat and keep it away from metal or magnetic objects. The calculated bearing remains available even when a compass sensor is unavailable.',
            ),
          ),
        ),
      ],
    );
  }
}

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({required this.reading});

  final CompassReading reading;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message, color) = switch (reading.calibrationState) {
      CompassCalibrationState.ready => (
        Icons.check_circle_outline,
        'Compass ready',
        'Turn until the blue arrow points straight ahead.',
        SukunColors.success,
      ),
      CompassCalibrationState.needsCalibration => (
        Icons.screen_rotation_alt_outlined,
        'Calibrate the compass',
        'Move the phone slowly in a figure-eight pattern, then hold it flat.',
        SukunColors.saffron,
      ),
      CompassCalibrationState.unavailable => (
        Icons.explore_off_outlined,
        'Compass sensor unavailable',
        'Use the displayed bearing with another trusted compass.',
        SukunColors.error,
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassDialPainter extends CustomPainter {
  const _CompassDialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final ring = Paint()
      ..color = SukunColors.deepTide
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ring);
    final tick = Paint()
      ..color = SukunColors.nightNavy.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    for (var degrees = 0; degrees < 360; degrees += 30) {
      final angle = degrees * math.pi / 180 - math.pi / 2;
      final outer = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 10),
        center.dy + math.sin(angle) * (radius - 10),
      );
      canvas.drawLine(inner, outer, tick);
    }
    final north = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: SukunColors.nightNavy,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    north.paint(canvas, Offset(center.dx - north.width / 2, 13));
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) => false;
}
