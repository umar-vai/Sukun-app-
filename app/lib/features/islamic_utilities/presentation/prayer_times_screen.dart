import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_schedule.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';

class PrayerTimesScreen extends ConsumerStatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  ConsumerState<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends ConsumerState<PrayerTimesScreen> {
  late Future<_PrayerPageData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_PrayerPageData> _load() async {
    final settings = await ref.read(utilityPreferencesStoreProvider).load();
    return _PrayerPageData(
      settings: settings,
      schedule: settings.isComplete
          ? ref
                .read(prayerCalculationServiceProvider)
                .calculate(settings: settings, now: DateTime.now())
          : null,
    );
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _refresh() async {
    final updated = await _load();
    if (!mounted) return;
    setState(() {
      _data = Future.value(updated);
    });
  }

  Future<void> _configure() async {
    final saved = await context.push<bool>('/prayer-times/settings');
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer times'),
        actions: [
          IconButton(
            onPressed: () => context.push('/qibla'),
            icon: const Icon(Icons.explore_outlined),
            tooltip: 'Open Qibla compass',
          ),
          IconButton(
            onPressed: _configure,
            icon: const Icon(Icons.tune),
            tooltip: 'Prayer settings',
          ),
        ],
      ),
      body: FutureBuilder<_PrayerPageData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Calculating prayer times');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message:
                  'Prayer times could not be calculated. ${snapshot.error}',
              onRetry: _reload,
            );
          }
          final data = snapshot.data!;
          if (!data.settings.isComplete) {
            return _SetupRequired(onConfigure: _configure);
          }
          return _PrayerScheduleView(data: data, onRefresh: _refresh);
        },
      ),
    );
  }
}

class _PrayerPageData {
  const _PrayerPageData({required this.settings, required this.schedule});

  final PrayerUtilitySettings settings;
  final PrayerDaySchedule? schedule;
}

class _SetupRequired extends StatelessWidget {
  const _SetupRequired({required this.onConfigure});

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
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: SukunColors.mist,
                  foregroundColor: SukunColors.deepTide,
                  child: Icon(Icons.schedule_outlined, size: 30),
                ),
                const SizedBox(height: 18),
                Text(
                  'Set up prayer times',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Choose these settings before calculation:'),
                const SizedBox(height: 8),
                const Text(
                  '• Location\n• Calculation method\n• Asr convention',
                ),
                const SizedBox(height: 8),
                const Text('Nothing is selected automatically.'),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onConfigure,
                  icon: const Icon(Icons.tune),
                  label: const Text('Choose settings'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrayerScheduleView extends StatelessWidget {
  const _PrayerScheduleView({required this.data, required this.onRefresh});

  final _PrayerPageData data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final schedule = data.schedule!;
    final settings = data.settings;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text(
            _longDate(schedule.date),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          Card(
            color: SukunColors.sukunBlue,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NEXT PRAYER',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          schedule.nextPrayer.label,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                      Text(
                        _time(context, schedule.nextPrayer.time),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Most recent prayer: ${schedule.currentPrayer.label}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text("Today's times", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < schedule.entries.length;
                  index++
                ) ...[
                  _PrayerRow(
                    entry: schedule.entries[index],
                    isCurrent:
                        schedule.entries[index].id == schedule.currentPrayer.id,
                  ),
                  if (index < schedule.entries.length - 1)
                    const Divider(height: 1, indent: 20, endIndent: 20),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: SukunColors.mist,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          settings.location!.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(settings.calculationMethod!.label),
                  Text('${settings.asrConvention!.label} Asr convention'),
                  const SizedBox(height: 10),
                  const Text(
                    'Calculated times may differ from a local mosque timetable. Follow trusted local guidance where applicable.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/qibla'),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Open Qibla direction'),
          ),
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({required this.entry, required this.isCurrent});

  final PrayerTimeEntry entry;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isCurrent ? SukunColors.mist : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Icon(
            entry.isPrayer
                ? Icons.nights_stay_outlined
                : Icons.wb_sunny_outlined,
            color: isCurrent ? SukunColors.deepTide : SukunColors.nightNavy,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.label,
              style: TextStyle(fontWeight: isCurrent ? FontWeight.w600 : null),
            ),
          ),
          Text(
            _time(context, entry.time),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _time(BuildContext context, DateTime value) =>
    TimeOfDay.fromDateTime(value).format(context);

String _longDate(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
