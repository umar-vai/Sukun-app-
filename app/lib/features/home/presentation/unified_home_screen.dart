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
  Future<PatientDay>? _patientDay;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _prayer = _readPrayer();
    if (widget.isPatient) {
      _patientDay = ref.read(patientCareRepositoryProvider).getToday();
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

  Future<void> _refresh() async {
    final prayer = _readPrayer();
    final patient = widget.isPatient
        ? ref.read(patientCareRepositoryProvider).getToday()
        : null;
    setState(() {
      _prayer = prayer;
      _patientDay = patient;
    });
    try {
      await prayer;
      if (patient != null) await patient;
    } catch (_) {
      // Each tile presents a friendly, independently retryable state.
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
              if (widget.isPatient && _patientDay != null) ...[
                const SizedBox(height: 14),
                _PatientHomeSummary(dayFuture: _patientDay!),
              ],
              if (widget.isSignedInMember || widget.isPatient) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push('/my-routines'),
                  icon: const Icon(Icons.checklist_rtl_rounded),
                  label: const Text('আমার ব্যক্তিগত রুটিন'),
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

class _PatientHomeSummary extends StatelessWidget {
  const _PatientHomeSummary({required this.dayFuture});

  final Future<PatientDay> dayFuture;

  @override
  Widget build(BuildContext context) => SukunSurface(
    tone: SukunSurfaceTone.soft,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'আজকের কাজ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/patient/today'),
              child: const Text('সব কাজ দেখুন'),
            ),
          ],
        ),
        FutureBuilder<PatientDay>(
          future: dayFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('কাজের সারাংশ আনা হচ্ছে…');
            }
            if (snapshot.hasError) {
              return const Text('এখন কাজের সারাংশ আনা যাচ্ছে না।');
            }
            final day = snapshot.data!;
            if (day.activePlan == null) {
              return const Text('আপনার জন্য এখনো কোনো পরিকল্পনা চালু হয়নি।');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.tasks.length}টির মধ্যে ${day.completedCount}টি সম্পন্ন',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: day.completionRatio,
                  borderRadius: BorderRadius.circular(12),
                  minHeight: 5,
                ),
                if (day.nextTask != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'পরবর্তী কাজ: ${day.nextTask!.action.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    ),
  );
}
