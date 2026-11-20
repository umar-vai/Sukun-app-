import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/app/router/shared_user_navigation.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/sukun_bangla_format.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_schedule.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_providers.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/personal_routines/data/personal_routine_repository.dart';
import 'package:sukun_life/features/home/domain/home_next_actions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';

/// The approved free challenge is visible again on the shared home screen.
const bool _showFortyDayChallenge = bool.fromEnvironment(
  'SUKUN_SHOW_40_DAY_CHALLENGE',
  defaultValue: true,
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
      allDoneToday:
          !planUnavailable &&
          !personalUnavailable &&
          HomeNextActions.allDoneToday(
            patientDay: day,
            routines: routines,
            actions: actions,
            outcomes: outcomes,
          ),
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

  /// Opens a task screen, then re-reads today's tasks so a finished amal
  /// never lingers as "next" when the user comes back to Home.
  Future<void> _openAndRefresh(String route) async {
    await context.push<void>(route);
    if (mounted) await _refresh();
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
            padding: const EdgeInsets.only(bottom: 30),
            children: [
              SukunHeroHeader(
                greeting: _HomeGreeting(
                  displayName: widget.displayName,
                  onDark: true,
                ),
                overlap: _upcoming == null
                    ? null
                    : _UnifiedNextTasks(
                        future: _upcoming!,
                        isPatient: widget.isPatient,
                        onOpen: _openAndRefresh,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 14),
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
                              child: Text(
                                'রুকইয়াহ ৪০ দিনের চ্যালেঞ্জ',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    SukunSectionHeader(
                      title: 'পাঠ ও অডিও',
                      subtitle: 'সহজে আপনার পছন্দের বিভাগে যান',
                      action: TextButton(
                        onPressed: () => context.push(
                          widget.isPatient
                              ? '/patient/resources'
                              : '/resources',
                        ),
                        child: const Text('সব দেখুন'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth < 340
                            ? 3
                            : constraints.maxWidth < 620
                            ? 4
                            : 8;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent: 98,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                              ),
                          itemCount: resourceSections.length,
                          itemBuilder: (context, index) {
                            final item = resourceSections[index];
                            return _HomeResourceTile(
                              key: Key('home-resource-${item.slug}'),
                              icon: item.icon,
                              label: item.titleBn,
                              onTap: () =>
                                  context.push('/resources/${item.slug}'),
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
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SukunColors.deepTide,
        foregroundColor: Colors.white,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const SukunLifeLogo(height: 30),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
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
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        key: const Key('home-compact-prayer'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: SukunColors.nightNavy,
          borderRadius: BorderRadius.circular(SukunRadius.card),
        ),
        child: FutureBuilder<_PrayerSummary?>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.hasError ? null : snapshot.data;
            final schedule = data?.schedule;
            if (schedule != null) _lastSchedule = schedule;
            final current = schedule?.currentPrayer;
            final next = schedule?.nextPrayer;
            final sunrise = schedule?.entries
                .where((entry) => entry.id == 'sunrise')
                .firstOrNull;
            final sunriseBreak =
                schedule != null && isSunriseBreak(schedule, _now);
            final windowEnd = schedule == null
                ? null
                : prayerWindowEnd(schedule, _now);
            final windowStart = sunriseBreak ? sunrise : current;
            final prayers = schedule?.entries
                .where((entry) => entry.isPrayer)
                .toList(growable: false);
            final remaining = windowEnd?.time.difference(_now);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: const BoxDecoration(color: SukunColors.navySoft),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          key: const Key('home-prayer-location-action'),
                          onTap: () => context.push('/prayer-times/settings'),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 17,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  data?.locationName ?? 'শহর নির্বাচন',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        schedule == null
                            ? 'নামাজের সময়'
                            : DateFormat(
                                'EEE, d MMM',
                                'en',
                              ).format(schedule.date),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'নামাজের সময় হিসাব হচ্ছে…',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                else if (current == null ||
                    next == null ||
                    prayers == null ||
                    windowStart == null ||
                    windowEnd == null ||
                    remaining == null)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: TextButton.icon(
                      onPressed: () => context.push('/prayer-times/settings'),
                      icon: const Icon(Icons.location_on_outlined),
                      label: const Text(
                        'নামাজের সময় দেখতে শহর ও পদ্ধতি সেট করুন',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 14, 13, 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final ringSize = constraints.maxWidth < 290
                            ? 91.0
                            : 112.0;
                        return Row(
                          children: [
                            SizedBox(
                              height: ringSize,
                              width: ringSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      key: const Key(
                                        'home-prayer-progress-ring',
                                      ),
                                      value: sunriseBreak
                                          ? 0.0
                                          : prayerWindowProgress(
                                              windowStart,
                                              windowEnd,
                                              _now,
                                            ),
                                      strokeWidth: 5,
                                      strokeCap: StrokeCap.round,
                                      color: SukunColors.sukunBlue,
                                      backgroundColor: const Color(0xFF36576D),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          sunriseBreak
                                              ? 'যোহর পর্যন্ত'
                                              : current.id == 'fajr'
                                              ? 'ফজরের শেষ'
                                              : 'পরের ওয়াক্ত',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFFB3D5E6),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          formatPrayerCountdown(remaining),
                                          key: const Key(
                                            'home-next-prayer-countdown',
                                          ),
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: ringSize < 100 ? 12 : 14,
                                            fontWeight: FontWeight.w800,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        const Text(
                                          'বাকি',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFFB3D5E6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'এখন',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFB3D5E6),
                                    ),
                                  ),
                                  Text(
                                    sunriseBreak
                                        ? 'ওয়াক্তের বিরতি'
                                        : prayerNamesForHome(current.id),
                                    key: const Key('home-current-prayer-name'),
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _HomePrayerWindowTime(
                                          title: sunriseBreak
                                              ? 'সূর্যোদয়'
                                              : 'শুরু',
                                          time: windowStart.time,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _HomePrayerWindowTime(
                                          title: sunriseBreak ? 'যোহর' : 'শেষ',
                                          time: windowEnd.time,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Row(
                      children: [
                        for (final entry in prayers)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: HomePrayerTimeChip(
                                entry: entry,
                                highlighted:
                                    !sunriseBreak && entry.id == current.id,
                                width: double.infinity,
                                onDarkBackground: true,
                                onTap: () => context.push('/prayer-times'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () => context.push('/qibla'),
                          icon: const Icon(Icons.explore_outlined, size: 16),
                          label: const Text('কিবলা'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD2EAF6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push('/prayer-times'),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                          label: const Text('পূর্ণ সময়সূচি'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _HomePrayerWindowTime extends StatelessWidget {
  const _HomePrayerWindowTime({required this.title, required this.time});

  final String title;
  final DateTime time;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF214258),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFF37566B)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Color(0xFFB3D5E6), fontSize: 10),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            MaterialLocalizations.of(context)
                .formatTimeOfDay(TimeOfDay.fromDateTime(time)),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Fajr ends at sunrise, not when Dhuhr begins.
PrayerTimeEntry prayerWindowEnd(PrayerDaySchedule schedule, DateTime now) {
  final sunrise = schedule.entries
      .where((entry) => entry.id == 'sunrise')
      .firstOrNull;
  if (schedule.currentPrayer.id == 'fajr' &&
      sunrise != null &&
      now.isBefore(sunrise.time)) {
    return sunrise;
  }
  return schedule.nextPrayer;
}

/// After sunrise and before Dhuhr the Fajr window has already ended.
bool isSunriseBreak(PrayerDaySchedule schedule, DateTime now) {
  final sunrise = schedule.entries
      .where((entry) => entry.id == 'sunrise')
      .firstOrNull;
  return schedule.currentPrayer.id == 'fajr' &&
      sunrise != null &&
      !now.isBefore(sunrise.time);
}

/// Fraction elapsed between the actual prayer boundaries, clamped to [0, 1].
double prayerWindowProgress(
  PrayerTimeEntry current,
  PrayerTimeEntry next,
  DateTime now,
) {
  final window = next.time.difference(current.time).inSeconds;
  if (window <= 0) return 0;
  return (now.difference(current.time).inSeconds / window).clamp(0.0, 1.0);
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
    this.width = 61,
    this.onDarkBackground = false,
    this.onTap,
  });

  final PrayerTimeEntry entry;
  final bool highlighted;
  final double width;
  final bool onDarkBackground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = highlighted
        ? Colors.white
        : onDarkBackground
        ? const Color(0xFFE5F1F7)
        : Theme.of(context).colorScheme.onSurface;
    final accent = onDarkBackground
        ? const Color(0xFFB3D5E6)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = switch (entry.id) {
      'fajr' => Icons.wb_twilight_outlined,
      'dhuhr' => Icons.wb_sunny_outlined,
      'asr' => Icons.cloud_outlined,
      'maghrib' => Icons.wb_twilight_outlined,
      'isha' => Icons.nightlight_round,
      _ => Icons.schedule_outlined,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        key: Key('home-prayer-chip-${entry.id}'),
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        decoration: BoxDecoration(
          color: highlighted ? SukunColors.deepTide : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _prayerLabel(entry.id),
              key: Key('home-prayer-label-${entry.id}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                MaterialLocalizations.of(context)
                    .formatTimeOfDay(TimeOfDay.fromDateTime(entry.time)),
                key: Key('home-prayer-time-${entry.id}'),
                maxLines: 1,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Icon(icon, color: highlighted ? Colors.white70 : accent, size: 17),
          ],
        ),
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
    this.allDoneToday = false,
  });

  final List<HomeNextAction> actions;
  final PatientDay? patientDay;
  final bool planUnavailable;
  final bool personalUnavailable;

  /// Everything for today is finished: Home shows the green note.
  final bool allDoneToday;
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({required this.displayName, this.onDark = false});

  final String? displayName;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strong = onDark ? Colors.white : SukunColors.nightNavy;
    final soft = onDark ? Colors.white70 : SukunColors.muted;
    final accent = onDark ? SukunColors.saffron : theme.colorScheme.secondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                banglaWeekdayDate(DateTime.now()),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                displayName == null
                    ? 'আসসালামু আলাইকুম'
                    : 'আসসালামু আলাইকুম, $displayName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: soft),
              ),
              const SizedBox(height: 2),
              Text(
                'আপনার প্রতিদিনের সুকুন',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: strong,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: onDark
              ? Colors.white.withValues(alpha: 0.14)
              : theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: onDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            key: const Key('universal-announcements-shortcut'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/announcements'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 22,
                        color: onDark
                            ? Colors.white
                            : theme.colorScheme.secondary,
                      ),
                      Positioned(
                        right: 1,
                        top: 1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: SukunColors.saffron,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: onDark
                                  ? SukunColors.deepTide
                                  : theme.colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'নোটিশ',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: onDark
                          ? Colors.white
                          : theme.colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeResourceTile extends StatelessWidget {
  const _HomeResourceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Column(
            children: [
              SukunIconBadge(icon: icon, size: 40),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's overview: plan progress and the single next action, with one
/// clear primary call to action (FINAL_UI_REFERENCE §6).
class _UnifiedNextTasks extends StatelessWidget {
  const _UnifiedNextTasks({
    required this.future,
    required this.isPatient,
    required this.onOpen,
  });

  final Future<_HomeTasksData> future;
  final bool isPatient;

  /// Opens a route and re-reads today's tasks when the user comes back.
  final Future<void> Function(String route) onOpen;

  @override
  Widget build(BuildContext context) => SukunSurface(
    key: const Key('home-unified-next-tasks'),
    padding: const EdgeInsets.all(18),
    child: FutureBuilder<_HomeTasksData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _TodayLoading();
        }
        final data = snapshot.data;
        final day = data?.patientDay;
        final plan = day?.activePlan;
        final next = data?.actions.firstOrNull;
        final later = data == null
            ? const <HomeNextAction>[]
            : data.actions.skip(1).take(2).toList(growable: false);
        final hasPlan = isPatient && plan != null && day!.tasks.isNotEmpty;
        final allDone =
            data?.allDoneToday == true ||
            (hasPlan && day.completedCount == day.tasks.length);
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (hasPlan)
                  _ProgressRing(
                    ratio: day.completionRatio,
                    label:
                        '${banglaDigits((day.completionRatio * 100).round())}%',
                  )
                else
                  const SukunIconBadge(
                    icon: Icons.self_improvement_rounded,
                    size: 56,
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPlan ? 'আজকের পরিকল্পনা' : 'আজকের আমল',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: SukunColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasPlan ? plan.name : 'আপনার রুটিন',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hasPlan) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${banglaDigits(day.tasks.length)}টির মধ্যে '
                          '${banglaDigits(day.completedCount)}টি সম্পন্ন',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: SukunColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (allDone)
              const _TodayAllDone(key: Key('home-all-done'))
            else if (next != null) ...[
              _NextActionRow(action: next),
              for (final item in later) _LaterActionRow(action: item),
            ] else
              Text(
                data == null
                    ? 'রুটিন খুলে আমল দেখুন।'
                    : data.planUnavailable || data.personalUnavailable
                    ? 'রুটিন থেকে পরবর্তী আমল দেখুন।'
                    : 'এই মুহূর্তে কোনো বাকি আমল নেই।',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SukunColors.muted,
                ),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('home-open-today'),
              onPressed: () => onOpen(
                next?.route ?? (hasPlan ? '/patient/today' : '/my-routines'),
              ),
              icon: Icon(
                next == null
                    ? Icons.checklist_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                next == null
                    ? (hasPlan ? 'আজকের কাজ দেখুন' : 'রুটিন খুলুন')
                    : 'শুরু করুন',
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _NextActionRow extends StatelessWidget {
  const _NextActionRow({required this.action});

  final HomeNextAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = action.dueAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.schedule_rounded,
              size: 21,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'পরবর্তী',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action.title,
                  key: const Key('home-next-amal-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action.origin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: SukunColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (due != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                banglaClock(due),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A quieter row for the next one or two actions after the main one.
class _LaterActionRow extends StatelessWidget {
  const _LaterActionRow({required this.action});

  final HomeNextAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = action.dueAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: SukunColors.border, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              action.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (due != null)
            Text(
              banglaClock(due),
              style: theme.textTheme.bodySmall?.copyWith(
                color: SukunColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.ratio, required this.label});

  final double ratio;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 64,
      height: 64,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayAllDone extends StatelessWidget {
  const _TodayAllDone({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SukunColors.successSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: SukunColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'আজকের সব কাজ সম্পন্ন। আলহামদুলিল্লাহ!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: SukunColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayLoading extends StatelessWidget {
  const _TodayLoading();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primaryContainer;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bar(90, 10), const SizedBox(height: 8), bar(160, 14)],
            ),
          ],
        ),
        const SizedBox(height: 16),
        bar(double.infinity, 58),
        const SizedBox(height: 10),
        Semantics(
          label: 'পরবর্তী আমল দেখা হচ্ছে…',
          child: const SizedBox(height: 1),
        ),
      ],
    );
  }
}
