import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_providers.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';
import 'package:uuid/uuid.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key, this.displayName});

  final String? displayName;

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  late Future<PatientDay> _day;
  String? _updatingTaskId;

  @override
  void initState() {
    super.initState();
    _day = _load();
  }

  Future<PatientDay> _load() async {
    final day = await ref.read(patientCareRepositoryProvider).getToday();
    unawaited(ref.read(notificationCoordinatorProvider).syncIfEnabled());
    return day;
  }

  void _reload() {
    setState(() {
      _day = _load();
    });
  }

  Future<void> _record(
    PatientTask task,
    PatientTaskStatus status, {
    DateTime? snoozedUntil,
    String? skipReason,
  }) async {
    if (_updatingTaskId != null) return;
    setState(() => _updatingTaskId = task.id);
    try {
      final updated = await ref
          .read(patientCareRepositoryProvider)
          .recordTask(
            task: task,
            status: status,
            clientEventId: const Uuid().v4(),
            snoozedUntil: snoozedUntil,
            skipReason: skipReason,
          );
      final notifications = ref.read(notificationCoordinatorProvider);
      if (status == PatientTaskStatus.snoozed && snoozedUntil != null) {
        unawaited(notifications.scheduleSnooze(updated, snoozedUntil));
      } else {
        unawaited(notifications.cancelTask(updated));
      }
      final currentDay = await _day;
      if (!mounted) return;
      setState(() {
        _day = Future.value(currentDay.replaceTask(updated));
      });
      if (updated.isPendingSync) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved securely on this device. It will sync automatically.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _updatingTaskId = null);
    }
  }

  Future<void> _openResource(PatientTask task) async {
    final resource = task.action.resource;
    if (resource == null) return;
    await context.push<void>(
      '/patient/resources/${Uri.encodeComponent(resource.id)}',
    );
  }

  Future<void> _snooze(PatientTask task) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SukunPageIntro(
              eyebrow: 'Reminder',
              title: 'Snooze this action',
              subtitle: 'Choose when you want to see it again.',
            ),
            const SizedBox(height: 18),
            SukunSurface(
              onTap: () => Navigator.pop(context, 15),
              radius: 18,
              padding: const EdgeInsets.all(16),
              child: const Row(
                children: [
                  SukunIconBadge(icon: Icons.timer_outlined, size: 42),
                  SizedBox(width: 12),
                  Expanded(child: Text('In 15 minutes')),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SukunSurface(
              onTap: () => Navigator.pop(context, 60),
              radius: 18,
              padding: const EdgeInsets.all(16),
              child: const Row(
                children: [
                  SukunIconBadge(icon: Icons.schedule_rounded, size: 42),
                  SizedBox(width: 12),
                  Expanded(child: Text('In 1 hour')),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (minutes == null) return;
    await _record(
      task,
      PatientTaskStatus.snoozed,
      snoozedUntil: DateTime.now().add(Duration(minutes: minutes)),
    );
  }

  Future<void> _skip(PatientTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SukunIconBadge(
                icon: Icons.skip_next_rounded,
                color: SukunColors.error,
                backgroundColor: SukunColors.errorSoft,
              ),
              const SizedBox(height: 16),
              Text(
                'Skip this action today?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'This will be recorded in your progress. It does not change the prescribed care plan.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Skip today'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep action'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await _record(task, PatientTaskStatus.skipped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PatientScaffold(
      title: 'Today',
      selectedIndex: 0,
      body: FutureBuilder<PatientDay>(
        future: _day,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'Preparing today’s plan');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final day = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              final updated = await _load();
              if (mounted) {
                setState(() {
                  _day = Future.value(updated);
                });
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                SukunPageIntro(
                  eyebrow: _longDate(DateTime.now()),
                  title:
                      'Assalamu Alaikum${widget.displayName == null ? '' : ', ${widget.displayName}'}',
                  subtitle: 'Here is your care plan for today.',
                ),
                const SizedBox(height: 24),
                if (day.activePlan == null)
                  const SukunSurface(
                    tone: SukunSurfaceTone.soft,
                    showBorder: false,
                    child: Row(
                      children: [
                        SukunIconBadge(icon: Icons.hourglass_empty_rounded),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Your practitioner has not published an active care plan yet.',
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _DayProgress(day: day),
                  const SizedBox(height: 18),
                  if (day.nextTask != null) ...[
                    const SukunSectionHeader(
                      title: 'Next action',
                      subtitle: 'Your most immediate pending task',
                    ),
                    const SizedBox(height: 10),
                    _TaskCard(
                      task: day.nextTask!,
                      featured: true,
                      busy: _updatingTaskId == day.nextTask!.id,
                      onDone: () =>
                          _record(day.nextTask!, PatientTaskStatus.completed),
                      onSnooze: () => _snooze(day.nextTask!),
                      onSkip: () => _skip(day.nextTask!),
                      onOpenResource: () => _openResource(day.nextTask!),
                    ),
                    const SizedBox(height: 22),
                  ],
                  SukunSectionHeader(
                    title: "Today's plan",
                    subtitle:
                        '${day.completedCount} of ${day.tasks.length} completed',
                  ),
                  const SizedBox(height: 10),
                  if (day.tasks.isEmpty)
                    const SukunSurface(
                      tone: SukunSurfaceTone.soft,
                      showBorder: false,
                      child: Text('There are no actions scheduled for today.'),
                    )
                  else
                    for (final task in day.tasks) ...[
                      _TaskCard(
                        task: task,
                        busy: _updatingTaskId == task.id,
                        onDone: () =>
                            _record(task, PatientTaskStatus.completed),
                        onSnooze: () => _snooze(task),
                        onSkip: () => _skip(task),
                        onOpenResource: () => _openResource(task),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayProgress extends StatelessWidget {
  const _DayProgress({required this.day});

  final PatientDay day;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      tone: SukunSurfaceTone.navy,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day.activePlan!.name,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: Colors.white),
                ),
              ),
              SukunStatusPill(
                label: '${(day.completionRatio * 100).round()}%',
                tone: SukunStatusTone.brand,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: day.completionRatio,
            color: SukunColors.saffron,
            backgroundColor: Colors.white24,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 8),
          Text(
            '${day.completedCount} of ${day.tasks.length} completed',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.busy,
    required this.onDone,
    required this.onSnooze,
    required this.onSkip,
    required this.onOpenResource,
    this.featured = false,
  });

  final PatientTask task;
  final bool busy;
  final bool featured;
  final VoidCallback onDone;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;
  final VoidCallback onOpenResource;

  @override
  Widget build(BuildContext context) {
    final canUpdate = task.status.canUpdate && !busy;
    return SukunSurface(
      tone: featured ? SukunSurfaceTone.soft : SukunSurfaceTone.white,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SukunIconBadge(
                size: 42,
                icon: task.status == PatientTaskStatus.completed
                    ? Icons.check_rounded
                    : featured
                    ? Icons.notifications_active_outlined
                    : Icons.circle_outlined,
                color: task.status == PatientTaskStatus.completed
                    ? SukunColors.success
                    : SukunColors.deepTide,
                backgroundColor: task.status == PatientTaskStatus.completed
                    ? SukunColors.successSoft
                    : Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.action.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(_timing(task)),
                  ],
                ),
              ),
              SukunStatusPill(
                label: task.status.label,
                tone: task.status == PatientTaskStatus.completed
                    ? SukunStatusTone.success
                    : task.status == PatientTaskStatus.skipped
                    ? SukunStatusTone.warning
                    : SukunStatusTone.brand,
              ),
            ],
          ),
          if (task.action.instruction?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(task.action.instruction!),
          ],
          if (task.action.countTarget != null ||
              task.action.durationMinutes != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (task.action.countTarget != null)
                  Chip(label: Text('${task.action.countTarget} repetitions')),
                if (task.action.durationMinutes != null)
                  Chip(label: Text('${task.action.durationMinutes} minutes')),
              ],
            ),
          ],
          if (task.action.resource != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onOpenResource,
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text('Open ${task.action.resource!.title}'),
            ),
          ],
          if (task.isPendingSync) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 18),
                SizedBox(width: 7),
                Expanded(child: Text('Waiting to sync securely')),
              ],
            ),
          ],
          if (task.status == PatientTaskStatus.snoozed &&
              task.snoozedUntil != null) ...[
            const SizedBox(height: 8),
            Text(
              'Snoozed until ${TimeOfDay.fromDateTime(task.snoozedUntil!).format(context)}',
            ),
          ],
          if (task.status.canUpdate) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: canUpdate ? onDone : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
                OutlinedButton(
                  onPressed: canUpdate ? onSnooze : null,
                  child: const Text('Snooze'),
                ),
                TextButton(
                  onPressed: canUpdate ? onSkip : null,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _timing(PatientTask task) {
  if (task.scheduledAt != null) {
    final local = task.scheduledAt!.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  final window = task.action.timeWindow;
  if (window == null || window.isEmpty) return 'Any time today';
  return window[0].toUpperCase() + window.substring(1);
}

String _longDate(DateTime date) {
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
