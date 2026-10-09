import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
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
            return AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
            );
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
        SukunSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SukunIconBadge(icon: Icons.location_off_outlined, size: 58),
              const SizedBox(height: 16),
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
        SukunPageIntro(
          eyebrow: 'Direction from $locationName',
          title: 'Face the Qibla',
          subtitle: reading.calibrationState ==
                  CompassCalibrationState.unavailable
              ? 'ব্রাউজারে কম্পাস সেন্সর পাওয়া যাচ্ছে না। নিচের কোণটি উত্তর দিক থেকে মেপে কিবলা নির্ধারণ করুন।'
              : 'Keep your phone flat and turn slowly until the marker points straight ahead.',
        ),
        const SizedBox(height: 24),
        SukunSurface(
          tone: SukunSurfaceTone.navy,
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
          child: Column(
            children: [
              SukunStatusPill(
                label: locationName,
                tone: SukunStatusTone.brand,
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 18),
              Center(
                child: Semantics(
                  label: 'Qibla bearing ${bearing.round()} degrees from north',
                  child: SizedBox.square(
                    dimension: 274,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size.square(274),
                          painter: const _CompassDialPainter(),
                        ),
                        Transform.rotate(
                          angle: relative * math.pi / 180,
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.navigation_rounded,
                                size: 94,
                                color: SukunColors.saffron,
                              ),
                              SizedBox(height: 62),
                            ],
                          ),
                        ),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: SukunColors.sukunBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: const Icon(
                            Icons.mosque_outlined,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${bearing.toStringAsFixed(1)}°',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(color: Colors.white),
              ),
              const Text('from North', style: TextStyle(color: Colors.white70)),
              if (reading.heading != null) ...[
                const SizedBox(height: 7),
                Text(
                  'Phone heading ${reading.heading!.round()}°',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _CalibrationCard(reading: reading),
        const SizedBox(height: 12),
        const SukunSurface(
          tone: SukunSurfaceTone.soft,
          showBorder: false,
          radius: 18,
          padding: EdgeInsets.all(17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                color: SukunColors.deepTide,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hold the phone flat and keep it away from metal or magnetic objects. The calculated bearing remains available even when a compass sensor is unavailable.',
                ),
              ),
            ],
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
    final tone = switch (reading.calibrationState) {
      CompassCalibrationState.ready => SukunSurfaceTone.success,
      CompassCalibrationState.needsCalibration => SukunSurfaceTone.warning,
      CompassCalibrationState.unavailable => SukunSurfaceTone.white,
    };
    return SukunSurface(
      tone: tone,
      radius: 20,
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
    );
  }
}

class _CompassDialPainter extends CustomPainter {
  const _CompassDialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final background = Paint()..color = SukunColors.navySoft;
    canvas.drawCircle(center, radius, background);
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ring);
    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
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
    for (final marker in const {
      'N': Alignment.topCenter,
      'E': Alignment.centerRight,
      'S': Alignment.bottomCenter,
      'W': Alignment.centerLeft,
    }.entries) {
      final painter = TextPainter(
        text: TextSpan(
          text: marker.key,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = marker.value.alongSize(size);
      final dx = offset.dx == 0
          ? 15.0
          : offset.dx == size.width
          ? size.width - painter.width - 15
          : offset.dx - painter.width / 2;
      final dy = offset.dy == 0
          ? 15.0
          : offset.dy == size.height
          ? size.height - painter.height - 15
          : offset.dy - painter.height / 2;
      painter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) => false;
}
