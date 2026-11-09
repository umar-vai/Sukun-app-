import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

/// Patient/member's own active actions, using owner-filtered repository rows.
/// An outcome of "skipped" never counts as completed.
class TodayRoutineSummary {
  const TodayRoutineSummary({required this.actions, required this.outcomes});

  final List<Map<String, dynamic>> actions;
  final Map<String, String> outcomes;

  int get total => actions.length;
  int get completed =>
      actions.where((action) => outcomes[action['id']] == 'done').length;
  int get remaining => total - completed;
  double get fraction => total == 0 ? 0 : completed / total;
}

class TodayRoutinePanel extends StatelessWidget {
  const TodayRoutinePanel({
    super.key,
    required this.routines,
    required this.actions,
    required this.outcomes,
    required this.onToggleDone,
    required this.onOpen,
    this.onOpenPatientToday,
    this.onOpenHistory,
    this.busy = false,
  });

  final List<Map<String, dynamic>> routines;
  final List<Map<String, dynamic>> actions;
  final Map<String, String> outcomes;
  final void Function(String actionId, bool currentlyDone) onToggleDone;
  final ValueChanged<String> onOpen;
  final VoidCallback? onOpenPatientToday;
  final VoidCallback? onOpenHistory;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final activeIds = {
      for (final routine in routines)
        if (routine['is_active'] == true) routine['id'],
    };
    final activeActions = actions
        .where(
          (action) =>
              action['is_active'] == true &&
              activeIds.contains(action['routine_id']),
        )
        .toList(growable: false);
    final summary = TodayRoutineSummary(
      actions: activeActions,
      outcomes: outcomes,
    );
    final theme = Theme.of(context);
    final percentage = (summary.fraction * 100).round();

    return ListView(
      key: const Key('today-routine-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        SukunSpace.page,
        SukunSpace.xs,
        SukunSpace.page,
        SukunSpace.sectionLarge,
      ),
      children: [
        // Patients: their approved care plan comes first, as one clear card
        // that opens the dedicated clinical "today" page.
        if (onOpenPatientToday != null) ...[
          SukunSurface(
            key: const Key('today-patient-plan-card'),
            tone: SukunSurfaceTone.navy,
            radius: SukunRadius.hero,
            onTap: onOpenPatientToday,
            child: Row(
              children: [
                const SukunIconBadge(
                  icon: Icons.assignment_turned_in_outlined,
                  color: Colors.white,
                  backgroundColor: Color(0x3328B8EF),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'সুকুন লাইফের নির্ধারিত আমল',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'আপনার অনুমোদিত চিকিৎসা-পরিকল্পনার আজকের কাজ',
                        style: TextStyle(color: Color(0xFFB9CCDB)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: SukunSpace.lg),
        ],
        SukunSurface(
          key: const Key('today-routine-overview'),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 280;
              final ring = SizedBox.square(
                dimension: 104,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: summary.fraction),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, animated, _) => Semantics(
                    label: 'আজকের রুটিন $percentage শতাংশ সম্পন্ন',
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            key: const Key('today-routine-progress-ring'),
                            value: animated,
                            strokeWidth: 9,
                            strokeCap: StrokeCap.round,
                            backgroundColor: SukunColors.mist,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              SukunColors.sukunBlue,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$percentage%',
                              key: const Key('today-routine-percentage'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'সম্পন্ন',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: SukunColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
              final counters = Column(
                crossAxisAlignment: narrow
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    'আজকের রুটিন',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'প্রতিটি আমল সম্পন্ন হলে এখানেই চিহ্নিত করুন',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: SukunColors.muted,
                    ),
                  ),
                  const SizedBox(height: SukunSpace.md),
                  Text(
                    '${summary.completed} টি সম্পন্ন',
                    key: const Key('today-routine-completed-count'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: SukunColors.deepTide,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.remaining} টি বাকি',
                    key: const Key('today-routine-remaining-count'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    'মোট ${summary.total} টি সক্রিয় করণীয়',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: SukunColors.muted,
                    ),
                  ),
                ],
              );
              return narrow
                  ? Column(
                      children: [
                        ring,
                        const SizedBox(height: SukunSpace.lg),
                        counters,
                      ],
                    )
                  : Row(
                      children: [
                        ring,
                        const SizedBox(width: SukunSpace.page),
                        Expanded(child: counters),
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: SukunSpace.section),
        SukunSectionHeader(
          title: 'আজকের করণীয়',
          subtitle: summary.total == 0
              ? 'কোনো সক্রিয় রুটিন নেই। আমার রুটিন থেকে করণীয় যোগ করুন।'
              : 'যেগুলো বাকি আছে সেগুলো আগে দেখানো হচ্ছে।',
        ),
        const SizedBox(height: SukunSpace.md),
        for (final action in [
          ...activeActions.where((a) => outcomes[a['id']] != 'done'),
          ...activeActions.where((a) => outcomes[a['id']] == 'done'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TodayActionTile(
              action: action,
              done: outcomes[action['id']] == 'done',
              busy: busy,
              onToggleDone: () => onToggleDone(
                action['id'] as String,
                outcomes[action['id']] == 'done',
              ),
              onOpen: () => onOpen(action['id'] as String),
            ),
          ),
        if (onOpenHistory != null) ...[
          const SizedBox(height: SukunSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenHistory,
              icon: const Icon(Icons.insights_outlined),
              label: const Text('আগের দিনের অগ্রগতি দেখুন'),
            ),
          ),
        ],
        const SizedBox(height: SukunSpace.sm),
        Text(
          'এই অগ্রগতি শুধু নিজের সম্পন্ন করা রুটিনের হিসাব; চিকিৎসার ফলাফল নয়।',
          style: theme.textTheme.bodySmall?.copyWith(color: SukunColors.muted),
        ),
      ],
    );
  }
}

class _TodayActionTile extends StatelessWidget {
  const _TodayActionTile({
    required this.action,
    required this.done,
    required this.busy,
    required this.onToggleDone,
    required this.onOpen,
  });

  final Map<String, dynamic> action;
  final bool done;
  final bool busy;
  final VoidCallback onToggleDone;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => SukunSurface(
    key: Key('today-action-${action['id']}'),
    radius: SukunRadius.tile + 2,
    padding: EdgeInsets.zero,
    tone: done ? SukunSurfaceTone.soft : SukunSurfaceTone.white,
    showBorder: false,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          IconButton(
            key: Key('today-toggle-${action['id']}'),
            tooltip: done ? 'সম্পন্ন চিহ্ন সরান' : 'আজ সম্পন্ন হয়েছে',
            onPressed: busy ? null : onToggleDone,
            icon: Icon(
              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: done ? SukunColors.deepTide : SukunColors.nightNavy,
              size: 30,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action['title']?.toString() ?? 'করণীয়',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      done ? 'আজ সম্পন্ন' : 'বাকি · বিস্তারিত খুলুন',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: done ? SukunColors.deepTide : SukunColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'করণীয় ও রিসোর্স খুলুন',
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
          ),
        ],
      ),
    ),
  );
}
