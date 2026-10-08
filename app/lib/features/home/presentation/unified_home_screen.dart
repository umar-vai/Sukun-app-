import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_schedule.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_providers.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';

/// Shared public landing page. Personal care is loaded only for patient sessions.
class UnifiedHomeScreen extends ConsumerStatefulWidget {
  const UnifiedHomeScreen({
    super.key,
    required this.isPatient,
    this.displayName,
  });

  final bool isPatient;
  final String? displayName;

  @override
  ConsumerState<UnifiedHomeScreen> createState() => _UnifiedHomeScreenState();
}

class _UnifiedHomeScreenState extends ConsumerState<UnifiedHomeScreen> {
  late Future<_PrayerSummary?> _prayer;
  Future<PatientDay>? _patientDay;

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
      nextPrayer: schedule.nextPrayer,
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

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
        children: [
          Text(
            widget.displayName == null
                ? 'আসসালামু আলাইকুম'
                : 'আসসালামু আলাইকুম, ${widget.displayName}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: SukunColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'আপনার প্রতিদিনের সুকুন',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HomeUtilityTile(
                  icon: Icons.schedule_outlined,
                  title: 'নামাজের সময়',
                  onTap: () => context.push('/prayer-times'),
                  detail: FutureBuilder<_PrayerSummary?>(
                    future: _prayer,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Text('হিসাব করা হচ্ছে…');
                      }
                      final info = snapshot.data;
                      if (snapshot.hasError || info == null) {
                        return const Text('অবস্থান সেট করুন');
                      }
                      final formatted = MaterialLocalizations.of(context)
                          .formatTimeOfDay(
                            TimeOfDay.fromDateTime(info.nextPrayer.time),
                          );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${info.nextPrayer.label} · $formatted',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            info.locationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HomeUtilityTile(
                  icon: Icons.explore_outlined,
                  title: 'কিবলার দিক',
                  onTap: () => context.push('/qibla'),
                  detail: const Text('দিকনির্দেশনা দেখুন'),
                ),
              ),
            ],
          ),
          if (widget.isPatient && _patientDay != null) ...[
            const SizedBox(height: 14),
            _PatientHomeSummary(dayFuture: _patientDay!),
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
              final columns = constraints.maxWidth < 330 ? 2 : 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 102,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _homeShortcuts.length,
                itemBuilder: (context, index) {
                  final item = _homeShortcuts[index];
                  return SukunSurface(
                    padding: const EdgeInsets.all(8),
                    onTap: () => context.push('/resources/${item.slug}'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SukunIconBadge(icon: item.icon, size: 36),
                        const SizedBox(height: 7),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          if (!widget.isPatient) ...[
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
    );

    if (widget.isPatient) {
      return PatientScaffold(
        title: 'সুকুন লাইফ',
        selectedIndex: 0,
        body: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const SukunLifeLogo(height: 36),
        actions: [
          TextButton(
            onPressed: () => context.push('/login'),
            child: const Text('লগইন'),
          ),
        ],
      ),
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) context.go('/resources');
          if (index == 2) context.go('/login');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'হোম',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'পাঠ ও অডিও',
          ),
          NavigationDestination(
            icon: Icon(Icons.login_outlined),
            label: 'লগইন',
          ),
        ],
      ),
    );
  }
}

class _PrayerSummary {
  const _PrayerSummary({
    required this.nextPrayer,
    required this.locationName,
  });

  final PrayerTimeEntry nextPrayer;
  final String locationName;
}

class _HomeUtilityTile extends StatelessWidget {
  const _HomeUtilityTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SukunSurface(
    padding: const EdgeInsets.all(13),
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: SukunColors.deepTide, size: 20),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DefaultTextStyle(
          style: Theme.of(context).textTheme.bodySmall ??
              const TextStyle(fontSize: 12),
          child: detail,
        ),
        const SizedBox(height: 6),
      ],
    ),
  );
}

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

class _HomeShortcut {
  const _HomeShortcut(this.slug, this.title, this.icon);

  final String slug;
  final String title;
  final IconData icon;
}

const _homeShortcuts = <_HomeShortcut>[
  _HomeShortcut('dua-azkar', 'দোয়া ও যিকর', Icons.favorite_outline),
  _HomeShortcut('ruqyah', 'রুকইয়াহ', Icons.graphic_eq),
  _HomeShortcut('books-pdfs', 'বই ও পিডিএফ', Icons.picture_as_pdf_outlined),
  _HomeShortcut('articles-guides', 'আর্টিকেল ও গাইড', Icons.article_outlined),
  _HomeShortcut('audio', 'অডিও', Icons.headphones_outlined),
  _HomeShortcut('video', 'ভিডিও', Icons.ondemand_video_outlined),
];
