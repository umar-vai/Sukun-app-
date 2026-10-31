import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/app/router/shared_user_navigation.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_schedule.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_providers.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/personal_routines/data/personal_routine_repository.dart';
import 'package:sukun_life/features/home/domain/home_next_actions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';

/// The challenge remains in source but is hidden until an approved relaunch.
const bool _showFortyDayChallenge = bool.fromEnvironment(
  'SUKUN_SHOW_40_DAY_CHALLENGE',
  defaultValue: false,
);

/// Shared public landing page. Personal care is loaded only for patient sessions.
class UnifiedHomeScreen extends ConsumerStatefulWidget {
  const UnifiedHomeScreen({
    super.key,
    required this.isPatient,
    this.isSignedInMember = false,
    this.displayName,
  });

  final bool isPatient;
  final bool isSignedInMember;
  final String? displayName;

  @override
  ConsumerState<UnifiedHomeScreen> createState() => _UnifiedHomeScreenState();
}

class _UnifiedHomeScreenState extends ConsumerState<UnifiedHomeScreen> {
  late Future<_PrayerSummary?> _prayer;
  Future<_HomeTasksData>? _upcoming;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _prayer = _readPrayer();
    if (widget.isSignedInMember || widget.isPatient) {
      _upcoming = _readUpcoming();
    }
  }

  Future<_PrayerSummary?> _readPrayer() async {
    final settings = await ref.read(utilityPreferencesStoreProvider).load();
    if (!settings.isComplete) return null;
    final schedule = ref
        .read(prayerCalculationServiceProvider)
        .calculate(settings: settings, now: DateTime.now());
    return _PrayerSummary(
      schedule: schedule,
      locationName: settings.location!.name,
    );
  }

  Future<_HomeTasksData> _readUpcoming() async {
    // Re-check the verified auth identity after awaits. Old account data must
    // never appear when a different person signs in on the same device.
    final ownerAtStart = ref.read(appSessionProvider).value?.userId;
    if (ownerAtStart == null) {
      return const _HomeTasksData(actions: []);
    }

    PatientDay? day;
    bool planUnavailable = false;
    if (widget.isPatient) {
      try {
        day = await ref.read(patientCareRepositoryProvider).getToday();
      } catch (_) {
        planUnavailable = true;
      }
    }

    List<Map<String, dynamic>> routines = [];
    List<Map<String, dynamic>> actions = [];
    Map<String, String> outcomes = {};
    bool personalUnavailable = false;
    try {
      final repo = PersonalRoutineRepository(Supabase.instance.client);
      final rows = await Future.wait<Object>([
        repo.listRoutines(),
        repo.listActions(),
        repo.todaysOutcomes(DateTime.now()),
      ]);
      routines = rows[0] as List<Map<String, dynamic>>;
      actions = rows[1] as List<Map<String, dynamic>>;
      outcomes = rows[2] as Map<String, String>;
    } catch (_) {
      personalUnavailable = true;
    }

    if (ref.read(appSessionProvider).value?.userId != ownerAtStart) {
      return const _HomeTasksData(actions: []);
    }

    final settings = await ref.read(utilityPreferencesStoreProvider).load();
    return _HomeTasksData(
      patientDay: day,
      planUnavailable: planUnavailable,
      personalUnavailable: personalUnavailable,
      actions: HomeNextActions.select(
        now: DateTime.now(),
        patientDay: day,
        routines: routines,
        actions: actions,
        outcomes: outcomes,
        settings: settings,
        calculator: ref.read(prayerCalculationServiceProvider),
      ),
    );
  }

  Future<void> _refresh() async {
    final prayer = _readPrayer();
    final upcoming = widget.isPatient || widget.isSignedInMember
        ? _readUpcoming()
        : null;
    setState(() {
      _prayer = prayer;
      _upcoming = upcoming;
    });
    try {
      await prayer;
      if (upcoming != null) await upcoming;
    } catch (_) {
      // Keep independent prayer/resource UI usable on a transient failure.
    }
  }

  Future<void> _signOut() async {
    if (_signingOut || (!widget.isSignedInMember && !widget.isPatient)) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      // Router reacts to the verified signed-out Supabase auth event.
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('লগআউট করা যায়নি। আবার চেষ্টা করুন।')),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        key: const Key('public-home-content-width'),
        constraints: const BoxConstraints(maxWidth: 1140),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.displayName == null
                              ? 'আসসালামু আলাইকুম'
                              : 'আসসালামু আলাইকুম, ${widget.displayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: SukunColors.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'আপনার প্রতিদিনের সুকুন',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    key: const Key('universal-announcements-shortcut'),
                    onPressed: () => context.push('/announcements'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF805300),
                      backgroundColor: SukunColors.warningSoft,
                      side: const BorderSide(color: Color(0xFFE5BF56)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.notification_important_outlined,
                      size: 18,
                    ),
                    label: const Text(
                      'নোটিশ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CompactPrayerStrip(prayer: _prayer, reload: _readPrayer),
              if (_showFortyDayChallenge) ...[
                const SizedBox(height: 12),
                SukunSurface(
                  key: const Key('home-forty-day-challenge'),
                  tone: SukunSurfaceTone.soft,
                  onTap: () => context.push('/challenge/40-day'),
                  child: const Row(
                    children: [
                      Icon(Icons.event_available_outlined, size: 30),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '৪০ দিনের বিনামূল্যের চ্যালেঞ্জ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 4),
                            Text('৫টি ধাপ • নিজের অগ্রগতি সংরক্ষণ করুন'),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ],
              if (_upcoming != null) ...[
                const SizedBox(height: 12),
                _UnifiedNextTasks(future: _upcoming!),
              ],
              const SizedBox(height: 22),
              SukunSectionHeader(
                title: 'পাঠ ও অডিও',
                subtitle: 'সহজে আপনার পছন্দের বিভাগে যান',
                action: TextButton(
                  onPressed: () => context.push(
                    widget.isPatient ? '/patient/resources' : '/resources',
                  ),
                  child: const Text('সব দেখুন'),
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 520 ? 2 : 3;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 96,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: resourceSections.length,
                    itemBuilder: (context, index) {
                      final item = resourceSections[index];
                      return SukunSurface(
                        key: Key('home-resource-${item.slug}'),
                        padding: const EdgeInsets.all(7),
                        onTap: () => context.push('/resources/${item.slug}'),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SukunIconBadge(icon: item.icon, size: 32),
                            const SizedBox(height: 5),
                            Text(
                              item.titleBn,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              if (!widget.isPatient && !widget.isSignedInMember) ...[
                const SizedBox(height: 18),
                SukunSurface(
                  tone: SukunSurfaceTone.soft,
                  onTap: () => context.push('/login'),
                  child: const Row(
                    children: [
                      Icon(Icons.health_and_safety_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'সুকুন লাইফের রোগী? আপনার পরিকল্পনা দেখতে লগইন করুন।',
                        ),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const SukunLifeLogo(height: 36),
        actions: [
          TextButton(
            onPressed: _signingOut
                ? null
                : widget.isSignedInMember || widget.isPatient
                ? _signOut
                : () => context.push('/login'),
            child: Text(
              _signingOut
                  ? 'লগআউট হচ্ছে…'
                  : widget.isSignedInMember || widget.isPatient
                  ? 'লগআউট'
                  : 'লগইন',
            ),
          ),
        ],
      ),
      body: content,
      bottomNavigationBar: SukunBottomNavigation(
        selectedIndex: 0,
        onSelected: (index) {
          if (widget.isSignedInMember || widget.isPatient) {
            context.go(sharedUserRoutes[index]);
          } else {
            if (index == 1) context.go('/announcements');
          }
        },
        destinations: widget.isSignedInMember || widget.isPatient
            ? sharedUserDestinations
            : const [
                SukunNavDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'হোম',
                ),
                SukunNavDestination(
                  icon: Icons.campaign_outlined,
                  selectedIcon: Icons.campaign,
                  label: 'নোটিশ',
                ),
              ],
      ),
    );
  }
}

class _PrayerSummary {
  const _PrayerSummary({required this.schedule, required this.locationName});

  final PrayerDaySchedule schedule;
  final String locationName;
}

/// Compact five-prayer preview; never guesses missing location or method.
/// Compact five-prayer preview with a one-second countdown.
/// Recalculates at a waqt boundary or after the calendar day changes.
class _CompactPrayerStrip extends StatefulWidget {
  const _CompactPrayerStrip({required this.prayer, required this.reload});

  final Future<_PrayerSummary?> prayer;
  final Future<_PrayerSummary?> Function() reload;

  @override
  State<_CompactPrayerStrip> createState() => _CompactPrayerStripState();
}

class _CompactPrayerStripState extends State<_CompactPrayerStrip> {
  late Future<_PrayerSummary?> _future;
  Timer? _ticker;
  DateTime _now = DateTime.now();
  PrayerDaySchedule? _lastSchedule;
  bool _refreshing = false;
  int _secondsSinceRefresh = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.prayer;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      final next = _lastSchedule?.nextPrayer.time;
      _secondsSinceRefresh++;
      if (!_refreshing &&
          (_secondsSinceRefresh >= 60 ||
              (next != null && !_now.isBefore(next)))) {
        _secondsSinceRefresh = 0;
        _refreshing = true;
        _lastSchedule = null;
        setState(() => _future = widget.reload());
        _future.then(
          (_) => _refreshing = false,
          onError: (Object _) => _refreshing = false,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CompactPrayerStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prayer != widget.prayer) {
      _future = widget.prayer;
      _lastSchedule = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SukunSurface(
    key: const Key('home-compact-prayer'),
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_outlined, size: 18),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'পরবর্তী নামাজ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'কিবলার দিক',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.explore_outlined, size: 20),
              onPressed: () => context.push('/qibla'),
            ),
            IconButton(
              tooltip: 'সম্পূর্ণ নামাজের সময়সূচি',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right_rounded, size: 22),
              onPressed: () => context.push('/prayer-times'),
            ),
          ],
        ),
        FutureBuilder<_PrayerSummary?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('নামাজের সময় হিসাব হচ্ছে…'),
              );
            }
            final data = snapshot.data;
            if (snapshot.hasError || data == null) {
              return TextButton.icon(
                onPressed: () => context.push('/prayer-times/settings'),
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: const Text('নামাজের সময় দেখতে শহর সেট করুন'),
              );
            }
            _lastSchedule = data.schedule;
            final next = data.schedule.nextPrayer;
            final remaining = next.time.difference(_now);
            final prayers = data.schedule.entries
                .where((entry) => entry.isPrayer)
                .toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${prayerNamesForHome(next.id)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(next.time))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPrayerCountdown(remaining),
                      key: const Key('home-next-prayer-countdown'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in prayers)
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: HomePrayerTimeChip(
                            entry: entry,
                            highlighted: entry.id == next.id,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

String prayerNamesForHome(String id) => _prayerLabel(id);

String formatPrayerCountdown(Duration remaining) {
  final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
  final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
  final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final secs = (seconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$secs';
}

/// Next-prayer tile with explicit contrast in both light and dark mode.
class HomePrayerTimeChip extends StatelessWidget {
  const HomePrayerTimeChip({
    super.key,
    required this.entry,
    required this.highlighted,
  });

  final PrayerTimeEntry entry;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final foreground = highlighted
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return Container(
      key: Key('home-prayer-chip-${entry.id}'),
      width: 61,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
      decoration: BoxDecoration(
        color: highlighted ? SukunColors.deepTide : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            _prayerLabel(entry.id),
            key: Key('home-prayer-label-${entry.id}'),
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            MaterialLocalizations.of(context)
                .formatTimeOfDay(TimeOfDay.fromDateTime(entry.time)),
            key: Key('home-prayer-time-${entry.id}'),
            maxLines: 1,
            style: TextStyle(color: foreground, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

String _prayerLabel(String id) => switch (id) {
  'fajr' => 'ফজর',
  'dhuhr' => 'যোহর',
  'asr' => 'আসর',
  'maghrib' => 'মাগরিব',
  'isha' => 'ইশা',
  _ => id,
};

class _HomeTasksData {
  const _HomeTasksData({
    required this.actions,
    this.patientDay,
    this.planUnavailable = false,
    this.personalUnavailable = false,
  });

  final List<HomeNextAction> actions;
  final PatientDay? patientDay;
  final bool planUnavailable;
  final bool personalUnavailable;
}

class _UnifiedNextTasks extends StatelessWidget {
  const _UnifiedNextTasks({required this.future});

  final Future<_HomeTasksData> future;
  @override
  Widget build(BuildContext context) => SukunSurface(
    key: const Key('home-unified-next-tasks'),
    tone: SukunSurfaceTone.soft,
    padding: const EdgeInsets.all(14),
    onTap: () => context.push('/my-routines'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'আপনার পরবর্তী আমল',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<_HomeTasksData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('পরবর্তী আমল দেখা হচ্ছে…');
            }
            final data = snapshot.data;
            if (data == null) return const Text('রুটিন খুলে আমল দেখুন।');
            final next = data.actions.firstOrNull;
            if (next == null) {
              return Text(
                data.planUnavailable || data.personalUnavailable
                    ? 'রুটিন থেকে পরবর্তী আমল দেখুন।'
                    : 'এই মুহূর্তে কোনো বাকি আমল নেই।',
              );
            }
            return Row(
              children: [
                const Icon(Icons.schedule_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    next.title,
                    key: const Key('home-next-amal-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
