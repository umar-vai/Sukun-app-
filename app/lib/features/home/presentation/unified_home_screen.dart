import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/app/router/shared_user_navigation.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/sukun_bangla_format.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/core/widgets/sukun_glass.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_schedule.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_providers.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/personal_routines/data/personal_routine_repository.dart';
import 'package:sukun_life/features/home/domain/home_next_actions.dart';
import 'package:sukun_life/features/notice_center/data/notice_center_providers.dart';
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

class _UnifiedHomeScreenState extends ConsumerState<UnifiedHomeScreen>
    with WidgetsBindingObserver {
  late Future<_PrayerSummary?> _prayer;
  Future<_HomeTasksData>? _upcoming;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prayer = _readPrayer();
    if (widget.isSignedInMember || widget.isPatient) {
      _upcoming = _readUpcoming();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A reminder may have rung while the app was in the background.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(noticeCenterProvider);
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
    ref.invalidate(noticeCenterProvider);
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

  Future<void> _openNotices(NoticeCenterSummary? summary) async {
    // Open the section that has something new; amal comes first.
    final notices =
        summary != null &&
        summary.amalCount == 0 &&
        summary.unseenNoticeCount > 0;
    await context.push<void>(
      notices ? '/announcements?section=notices' : '/announcements',
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final noticeSummary = ref.watch(noticeCenterProvider).value;
    final noticeCount = noticeSummary?.total ?? 0;
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        key: const Key('public-home-content-width'),
        constraints: const BoxConstraints(maxWidth: 1140),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // The glass bottom menu floats over the list; keep the last
            // row reachable above it.
            padding: EdgeInsets.only(
              bottom: 30 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              SukunHeroHeader(
                greeting: _HomeGreeting(
                  displayName: widget.displayName,
                  onDark: true,
                  noticeCount: noticeCount,
                  onNotices: () => unawaited(_openNotices(noticeSummary)),
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
                    if (_showFortyDayChallenge) ...[
                      const SizedBox(height: 6),
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
                                'রুকইয়াহ ৪০ দিনের চ্যালেঞ্জ',
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
        titleSpacing: 14,
        toolbarHeight: 66,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const SukunLifeLogo(height: 30),
            ),
            const SizedBox(width: 10),
            // Current and next waqt only; the full timetable opens on tap.
            Expanded(
              child: _CompactPrayerStrip(prayer: _prayer, reload: _readPrayer),
            ),
          ],
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
      extendBody: true,
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
            : [
                const SukunNavDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'হোম',
                ),
                SukunNavDestination(
                  icon: Icons.campaign_outlined,
                  selectedIcon: Icons.campaign,
                  label: 'নোটিশ',
                  badgeCount: noticeCount,
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
  Widget build(BuildContext context) => FutureBuilder<_PrayerSummary?>(
    future: _future,
    builder: (context, snapshot) {
      final data = snapshot.hasError ? null : snapshot.data;
      final schedule = data?.schedule;
      if (schedule != null) _lastSchedule = schedule;
      final current = schedule?.currentPrayer;
      final sunriseBreak = schedule != null && isSunriseBreak(schedule, _now);
      final windowEnd = schedule == null
          ? null
          : prayerWindowEnd(schedule, _now);
      final remaining = windowEnd?.time.difference(_now);
      final ready =
          snapshot.connectionState != ConnectionState.waiting &&
          current != null &&
          windowEnd != null &&
          remaining != null;
      const soft = TextStyle(
        color: Colors.white70,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.1,
      );
      const strong = TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        height: 1.15,
      );
      final Widget body;
      if (!ready) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        body = InkWell(
          key: const Key('home-prayer-location-action'),
          onTap: () => context.push(
            loading ? '/prayer-times' : '/prayer-times/settings',
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.mosque_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('নামাজের সময়', style: strong, maxLines: 1),
                      Text(
                        loading ? 'হিসাব হচ্ছে…' : 'শহর ও পদ্ধতি সেট করুন',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: soft,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        final nowLabel = sunriseBreak
            ? 'বিরতি'
            : prayerNamesForHome(current.id);
        final nextLabel = sunriseBreak
            ? 'যোহর'
            : prayerNamesForHome(windowEnd.id);
        final nextTime = MaterialLocalizations.of(context)
            .formatTimeOfDay(TimeOfDay.fromDateTime(windowEnd.time));
        body = InkWell(
          onTap: () => context.push('/prayer-times'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('এখন', style: soft, maxLines: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          nowLabel,
                          key: const Key('home-current-prayer-name'),
                          maxLines: 1,
                          style: strong,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 26,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.white.withValues(alpha: 0.30),
                ),
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'পরের ওয়াক্ত $nextLabel · $nextTime',
                          key: const Key('home-next-prayer-name'),
                          maxLines: 1,
                          style: soft,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatPrayerCountdown(remaining),
                          key: const Key('home-next-prayer-countdown'),
                          maxLines: 1,
                          style: strong.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        );
      }
      return Semantics(
        button: true,
        label: 'নামাজের সময়সূচি',
        child: SukunGlass(
          key: const Key('home-compact-prayer'),
          tone: SukunGlassTone.onColor,
          blur: 16,
          borderRadius: BorderRadius.circular(16),
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(height: 46, child: body),
          ),
        ),
      );
    },
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
  'sunrise' => 'সূর্যোদয়',
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
  const _HomeGreeting({
    required this.displayName,
    required this.onNotices,
    this.onDark = false,
    this.noticeCount = 0,
  });

  final String? displayName;
  final bool onDark;

  /// Unread notices and due amal reminders; the badge is hidden at zero.
  final int noticeCount;
  final VoidCallback onNotices;

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
        SukunGlass(
          tone: onDark ? SukunGlassTone.onColor : SukunGlassTone.surface,
          blur: 14,
          borderRadius: BorderRadius.circular(16),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const Key('universal-announcements-shortcut'),
              borderRadius: BorderRadius.circular(16),
              onTap: onNotices,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Badge(
                      key: const Key('notice-count-badge'),
                      isLabelVisible: noticeCount > 0,
                      backgroundColor: SukunColors.error,
                      textColor: Colors.white,
                      offset: const Offset(7, -6),
                      label: Text(noticeCount > 9 ? '9+' : '$noticeCount'),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 22,
                        color: onDark
                            ? Colors.white
                            : theme.colorScheme.secondary,
                      ),
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
    return SukunGlass(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
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
