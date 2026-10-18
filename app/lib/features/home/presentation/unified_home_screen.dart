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
                      'গুরুত্বপূর্ণ নোটিশ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CompactPrayerStrip(prayer: _prayer),
              if (_upcoming != null) ...[
                const SizedBox(height: 12),
                _UnifiedNextTasks(
                  future: _upcoming!,
                  isPatient: widget.isPatient,
                ),
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
            if (index == 1) context.go('/resources');
            if (index == 2) context.go('/announcements');
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
                  icon: Icons.menu_book_outlined,
                  selectedIcon: Icons.menu_book,
                  label: 'উপকরণ',
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
class _CompactPrayerStrip extends StatelessWidget {
  const _CompactPrayerStrip({required this.prayer});

  final Future<_PrayerSummary?> prayer;

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
                'নামাজের সময়',
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
          future: prayer,
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
            final prayers = data.schedule.entries
                .where((entry) => entry.isPrayer)
                .toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in prayers)
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: Container(
                            width: 61,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: entry.id == data.schedule.nextPrayer.id
                                  ? SukunColors.paleBlue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _prayerLabel(entry.id),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  MaterialLocalizations.of(context)
                                      .formatTimeOfDay(
                                        TimeOfDay.fromDateTime(entry.time),
                                      ),
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
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
  const _UnifiedNextTasks({required this.future, required this.isPatient});

  final Future<_HomeTasksData> future;
  final bool isPatient;

  @override
  Widget build(BuildContext context) => SukunSurface(
    key: const Key('home-unified-next-tasks'),
    tone: SukunSurfaceTone.soft,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'আপনার পরবর্তী কাজ',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 7),
        FutureBuilder<_HomeTasksData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('আপনার করণীয় খোঁজা হচ্ছে…');
            }
            if (snapshot.hasError || snapshot.data == null) {
              return const Text(
                'এখন কাজগুলো আনা যাচ্ছে না। পরে আবার চেষ্টা করুন।',
              );
            }
            final data = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.patientDay?.activePlan != null) ...[
                  Text(
                    'আজকের পরিকল্পনা: ${data.patientDay!.completedCount}/${data.patientDay!.tasks.length} সম্পন্ন',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: data.patientDay!.completionRatio,
                  ),
                  const SizedBox(height: 7),
                ],
                if (data.actions.isEmpty)
                  const Text('এই মুহূর্তে কোনো বাকি কাজ নেই।'),
                for (final action in data.actions.take(3))
                  ListTile(
                    key: Key('upcoming-${action.id}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      action.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${action.origin} · ${HomeNextActions.dueLabel(action)}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(action.route),
                  ),
                if (data.planUnavailable || data.personalUnavailable)
                  const Text(
                    'কিছু কাজ লোড হয়নি। নিচের রুটিন বা পরিকল্পনা খুলে দেখুন।',
                  ),
                Wrap(
                  spacing: 6,
                  children: [
                    if (isPatient)
                      TextButton(
                        onPressed: () => context.push('/patient/today'),
                        child: const Text('সব রোগীর কাজ'),
                      ),
                    TextButton(
                      onPressed: () => context.push('/my-routines'),
                      child: const Text('আমার রুটিন'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
