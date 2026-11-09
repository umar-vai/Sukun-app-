import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/challenges/data/forty_day_challenge_repository.dart';
import 'package:sukun_life/features/challenges/domain/forty_day_challenge_content.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Free public campaign. Private progress belongs to the authenticated member
/// and is never inferred from a patient prescription or clinical record.
class FortyDayChallengeScreen extends ConsumerStatefulWidget {
  const FortyDayChallengeScreen({super.key});

  @override
  ConsumerState<FortyDayChallengeScreen> createState() =>
      _FortyDayChallengeScreenState();
}

class _FortyDayChallengeScreenState
    extends ConsumerState<FortyDayChallengeScreen> {
  late Future<ChallengeProgress?> _progress;
  bool _working = false;
  String? _loadedOwner;

  ChallengeRepository get _repo =>
      ChallengeRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _loadedOwner = ref.read(appSessionProvider).value?.userId;
    _progress = _loadedOwner == null ? Future.value(null) : _repo.load();
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _progress = _loadedOwner == null ? Future.value(null) : _repo.load();
      });
    }
  }

  Future<void> _act(Future<void> Function() callback) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await callback();
      _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('পরিবর্তন সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।'),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openResource(ChallengeResourceLink link) async {
    final uri = Uri.parse(link.url);
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Report a failed URL open without interrupting challenge tracking.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('লিংকটি খোলা যাচ্ছে না। আবার চেষ্টা করুন।'),
        ),
      );
    }
  }

  Widget _resourceTile(ChallengeResourceLink link) {
    final icon = switch (link.kind) {
      ChallengeResourceKind.pdf => Icons.picture_as_pdf_outlined,
      ChallengeResourceKind.audio => Icons.headphones_outlined,
      ChallengeResourceKind.assessment => Icons.fact_check_outlined,
      ChallengeResourceKind.community => Icons.groups_outlined,
    };
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(link.title),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => _openResource(link),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSessionProvider, (previous, next) {
      final owner = next.value?.userId;
      if (owner != _loadedOwner && mounted) {
        setState(() {
          _loadedOwner = owner;
          _progress = owner == null ? Future.value(null) : _repo.load();
        });
      }
    });
    final session = ref.watch(appSessionProvider).value;
    final eligible = session?.isMember == true || session?.isPatient == true;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('৪০ দিনের চ্যালেঞ্জ')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              Text(
                'রুকইয়াহ ৪০ দিনের চ্যালেঞ্জ',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'নিয়মিত আমল করার অভ্যাস গড়ে তুলুন, ধাপে ধাপে গাইড পড়ুন '
                'এবং নিজের অগ্রগতি অনুসরণ করুন। চ্যালেঞ্জটি বিনামূল্যে।',
              ),
              const SizedBox(height: 8),
              const Text(
                'শিফা একমাত্র আল্লাহর পক্ষ থেকেই আসে। '
                'এই চ্যালেঞ্জ চিকিৎসার বিকল্প বা রোগ নির্ণয়ের পদ্ধতি নয়।',
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: eligible
                      ? FutureBuilder<ChallengeProgress?>(
                          future: _progress,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            if (snapshot.hasError) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('চ্যালেঞ্জের তথ্য লোড করা যায়নি।'),
                                  TextButton(
                                    onPressed: _refresh,
                                    child: const Text('আবার চেষ্টা করুন'),
                                  ),
                                ],
                              );
                            }
                            final progress = snapshot.data;
                            if (progress == null) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'আপনি এখনো চ্যালেঞ্জে যোগ দেননি। '
                                    'বিনামূল্যে শুরু করলে আপনার দিনের অগ্রগতি '
                                    'আপনার অ্যাকাউন্টে সংরক্ষিত থাকবে।',
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    key: const Key('challenge-enroll'),
                                    onPressed: _working
                                        ? null
                                        : () => _act(
                                            () => _repo.enroll(DateTime.now()),
                                          ),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('বিনামূল্যে শুরু করুন'),
                                  ),
                                ],
                              );
                            }
                            final day = progress.dayAt(now);
                            final done = progress.completedDays.contains(day);
                            return Column(
                              key: const Key('challenge-progress'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  progress.complete
                                      ? '৪০ দিনের সব কাজ সম্পন্ন'
                                      : progress.isPaused
                                      ? 'বিরতিতে আছেন • দিন $day'
                                      : 'আজ আপনার চ্যালেঞ্জের দিন $day',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: progress.completedDays.length / 40,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${progress.completedDays.length}/৪০ দিন সম্পন্ন '
                                  '• ${progress.stageAt(now).title}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                if (!progress.isPaused && !progress.complete)
                                  FilledButton.icon(
                                    key: const Key('challenge-checkin'),
                                    onPressed: _working
                                        ? null
                                        : () => _act(
                                            () => done
                                                ? _repo.undoToday(progress, now)
                                                : _repo.markToday(
                                                    progress,
                                                    now,
                                                  ),
                                          ),
                                    icon: Icon(
                                      done
                                          ? Icons.undo
                                          : Icons.check_circle_outline,
                                    ),
                                    label: Text(
                                      done
                                          ? 'আজকের সম্পন্ন চিহ্ন সরান'
                                          : 'আজকের ধাপ সম্পন্ন করেছি',
                                    ),
                                  ),
                                TextButton.icon(
                                  key: const Key('challenge-pause-toggle'),
                                  onPressed: _working || progress.complete
                                      ? null
                                      : () => _act(
                                          () => progress.isPaused
                                              ? _repo.resume(
                                                  progress,
                                                  DateTime.now(),
                                                )
                                              : _repo.pause(
                                                  progress,
                                                  DateTime.now(),
                                                ),
                                        ),
                                  icon: Icon(
                                    progress.isPaused
                                        ? Icons.play_circle_outline
                                        : Icons.pause_circle_outline,
                                  ),
                                  label: Text(
                                    progress.isPaused
                                        ? 'বিরতি শেষ করে চালু করুন'
                                        : 'কিছুদিন বিরতি নিন',
                                  ),
                                ),
                                const Text(
                                  'বিরতির পর অগ্রগতি থাকবে। নিজের চিকিৎসার নির্দেশ অনুসরণ করুন।',
                                ),
                              ],
                            );
                          },
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('অগ্রগতি সংরক্ষণ করতে লগইন করুন।'),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              key: const Key('challenge-login'),
                              onPressed: () => context.push('/login'),
                              icon: const Icon(Icons.login),
                              label: const Text('লগইন করুন'),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'শুরু করার আগে',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text('পরিচিতি, সম্পূর্ণ বই ও সেলফ রুকইয়াহ ই-বুক'),
              ...challengeGettingStartedLinks.map(_resourceTile),
              const SizedBox(height: 20),
              Text(
                '৪০ দিনের ৫টি ধাপ',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'প্রতিটি ধাপের গাইড ও প্রয়োজনীয় অডিও খুলতে ট্যাপ করুন।',
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 680 ? 2 : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < fortyDayStages.length; i++)
                        SizedBox(
                          width: width,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(child: Text('${i + 1}')),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          fortyDayStages[i].title,
                                          key: Key('challenge-stage-${i + 1}'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'দিন ${fortyDayStages[i].firstDay}–'
                                    '${fortyDayStages[i].lastDay} • '
                                    '${fortyDayStages[i].description}',
                                  ),
                                  const Divider(height: 18),
                                  ...challengeStageLinks[i].map(_resourceTile),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'সহায়তা ও পরবর্তী করণীয়',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'লক্ষণ নিয়ে উদ্বেগ থাকলে সেলফ-অ্যাসেসমেন্ট দেখতে পারেন। '
                'এটি জিন, জাদু, বদনজর বা কোনো চিকিৎসাগত সমস্যা নিশ্চিত করে না। '
                'প্রয়োজনে উপযুক্ত চিকিৎসা পেশাজীবীর পরামর্শ নিন।',
              ),
              ...challengeSupportLinks.map(_resourceTile),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push('/resources/ruqyah'),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('আরও রুকইয়াহ পাঠ দেখুন'),
              ),
              const SizedBox(height: 8),
              const Text(
                'চ্যালেঞ্জের বিশেষ ওয়েবিনার ও লাইভ প্রশ্নোত্তরের '
                'সূচি ঘোষণা হলে নোটিশে দেখতে পাবেন।',
              ),
              TextButton.icon(
                onPressed: () => context.push('/announcements'),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('ওয়েবিনার ও নোটিশ দেখুন'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
