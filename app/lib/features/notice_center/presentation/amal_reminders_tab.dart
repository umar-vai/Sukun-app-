import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/notice_center/data/notice_center_providers.dart';
import 'package:sukun_life/features/notice_center/domain/amal_reminder.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_providers.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/personal_routines/data/personal_reminder_service.dart';
import 'package:uuid/uuid.dart';

/// Every amal whose reminder has rung today and is still open, whether or not
/// the phone notification was seen. Each can be opened or marked done here.
class AmalRemindersTab extends ConsumerStatefulWidget {
  const AmalRemindersTab({super.key});

  @override
  ConsumerState<AmalRemindersTab> createState() => _AmalRemindersTabState();
}

class _AmalRemindersTabState extends ConsumerState<AmalRemindersTab> {
  String? _completingId;

  Future<void> _open(AmalReminder item) async {
    await context.push<void>(item.route);
    if (mounted) ref.invalidate(noticeCenterProvider);
  }

  Future<void> _complete(AmalReminder item) async {
    if (_completingId != null) return;
    setState(() => _completingId = item.id);
    try {
      switch (item.kind) {
        case AmalReminderKind.care:
          final updated = await ref
              .read(patientCareRepositoryProvider)
              .recordTask(
                task: item.task!,
                status: PatientTaskStatus.completed,
                clientEventId: const Uuid().v4(),
              );
          unawaited(
            ref.read(notificationCoordinatorProvider).cancelTask(updated),
          );
        case AmalReminderKind.personal:
          await ref
              .read(personalReminderServiceProvider)
              .repository
              .recordOutcome(
                actionId: item.id,
                localDate: DateTime.now(),
                outcome: 'done',
              );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('আলহামদুলিল্লাহ, আমলটি সম্পন্ন হয়েছে।')),
      );
      ref.invalidate(noticeCenterProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('আমলটি সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।'),
        ),
      );
    } finally {
      if (mounted) setState(() => _completingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(noticeCenterProvider);
    return summary.when(
      loading: () => const AppLoadingState(label: 'আমলগুলো আনা হচ্ছে…'),
      error: (_, _) => AppErrorState(
        message: 'আমলগুলো এখন আনা যাচ্ছে না।',
        onRetry: () => ref.invalidate(noticeCenterProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () => ref.refresh(noticeCenterProvider.future),
        child: data.amalReminders.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 40),
                  AppEmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'এখন কোনো বাকি আমল নেই।',
                    message: 'রিমাইন্ডারের সময় হওয়া আমলগুলো সম্পন্ন না করা পর্যন্ত এখানে জমা থাকবে।',
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  SukunSpace.page,
                  SukunSpace.md,
                  SukunSpace.page,
                  SukunSpace.section,
                ),
                itemCount: data.amalReminders.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Text(
                      'নোটিফিকেশন মিস হলেও আজকের বাকি আমলগুলো এখান থেকে করতে পারবেন।',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: SukunColors.muted),
                    );
                  }
                  final item = data.amalReminders[index - 1];
                  return _AmalReminderCard(
                    item: item,
                    busy: _completingId == item.id,
                    enabled: _completingId == null,
                    onOpen: () => _open(item),
                    onComplete: () => _complete(item),
                  );
                },
              ),
      ),
    );
  }
}

class _AmalReminderCard extends StatelessWidget {
  const _AmalReminderCard({
    required this.item,
    required this.busy,
    required this.enabled,
    required this.onOpen,
    required this.onComplete,
  });

  final AmalReminder item;
  final bool busy;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(item.dueAt.toLocal()).format(context);
    return SukunSurface(
      key: Key('amal-reminder-${item.id}'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      radius: SukunRadius.tile + 2,
      onTap: enabled ? onOpen : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SukunIconBadge(
                icon: item.kind == AmalReminderKind.care
                    ? Icons.assignment_turned_in_outlined
                    : Icons.event_repeat_outlined,
                size: 42,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.originBn} · সময় $time',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: SukunColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: enabled ? onOpen : null,
                child: const Text('খুলুন'),
              ),
              const SizedBox(width: 6),
              FilledButton.tonalIcon(
                key: Key('amal-complete-${item.id}'),
                onPressed: enabled ? onComplete : null,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text('সম্পন্ন'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
