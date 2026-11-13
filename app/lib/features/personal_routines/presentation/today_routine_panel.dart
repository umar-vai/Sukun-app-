import 'package:flutter/material.dart';
import 'package:sukun_life/features/personal_routines/domain/routine_calendar.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/personal_routines/presentation/routine_hub_parts.dart';

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
    this.history = const [],
    this.today,
    this.busy = false,
  });

  final List<Map<String, dynamic>> routines;
  final List<Map<String, dynamic>> actions;
  final Map<String, String> outcomes;
  final void Function(String actionId, bool currentlyDone) onToggleDone;
  final ValueChanged<String> onOpen;
  final VoidCallback? onOpenPatientToday;
  final VoidCallback? onOpenHistory;

  /// Last days' outcome rows (`local_date`, `outcome`) for the streak strip.
  final List<Map<String, dynamic>> history;

  /// Overridable for tests; defaults to now.
  final DateTime? today;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final activeIds = {
      for (final routine in routines)
        if (routine['is_active'] == true) routine['id'],
    };
    final day = today ?? DateTime.now();
    final inActiveRoutines = [
      for (final action in actions)
        if (activeIds.contains(action['routine_id'])) action,
    ];
    final detoxDates = routineDetoxDates(inActiveRoutines);
    final activeActions = inActiveRoutines
        .where(
          (action) =>
              action['is_active'] == true &&
              routineActionRunsOn(action, day, detoxDates: detoxDates),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
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
                    'আজকের আমল',
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
        const SizedBox(height: SukunSpace.md),
        _StreakStrip(
          history: history,
          today: today ?? DateTime.now(),
          doneToday: summary.completed > 0,
          onOpenHistory: onOpenHistory,
        ),
        if (summary.total > 0 && summary.remaining == 0) ...[
          const SizedBox(height: SukunSpace.md),
          const TodayAllDoneCard(key: Key('today-all-done')),
        ],
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
                      done ? 'আজ সম্পন্ন' : 'বাকি',
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
            tooltip: 'করণীয় খুলুন',
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
          ),
        ],
      ),
    ),
  );
}

/// Green "all done" note shown on Today and on Home once every active
/// action of the day is marked complete.
class TodayAllDoneCard extends StatelessWidget {
  const TodayAllDoneCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: SukunColors.successSoft,
      borderRadius: BorderRadius.circular(SukunRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SukunRadius.card),
        child: Ink(
          padding: const EdgeInsets.all(SukunSpace.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SukunRadius.card),
            border: Border.all(
              color: SukunColors.success.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: SukunColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: SukunSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'মাশাআল্লাহ! আজকের সব আমল সম্পন্ন',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: SukunColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'আল্লাহ কবুল করুন। আগামীকাল আবার মনে করিয়ে দেওয়া হবে।',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: SukunColors.nightNavy.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seven small day dots (filled when something was done that day) with the
/// running streak, replacing the old separate Progress tab at a glance.
class _StreakStrip extends StatelessWidget {
  const _StreakStrip({
    required this.history,
    required this.today,
    required this.doneToday,
    this.onOpenHistory,
  });

  final List<Map<String, dynamic>> history;
  final DateTime today;
  final bool doneToday;
  final VoidCallback? onOpenHistory;

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = DateTime(today.year, today.month, today.day);
    final doneDates = <String>{
      for (final row in history)
        if (row['outcome'] == 'done') row['local_date'].toString(),
      if (doneToday) _key(base),
    };
    final streak = routineStreakDays(doneDates, base);
    const weekdays = ['সো', 'ম', 'বু', 'বৃ', 'শু', 'শ', 'র'];
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(base.year, base.month, base.day - i),
    ];
    final activeDays = days.where((d) => doneDates.contains(_key(d))).length;
    return SukunSurface(
      key: const Key('today-streak-strip'),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      onTap: onOpenHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_outlined,
                color: SukunColors.deepTide,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  streak == 0
                      ? 'ধারাবাহিকতা শুরু করুন'
                      : 'টানা ${_bnDigits(streak)} দিন আমল',
                  key: const Key('today-streak-label'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '৭ দিনে ${_bnDigits(activeDays)} দিন',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: SukunColors.muted,
                ),
              ),
              if (onOpenHistory != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: SukunColors.muted,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Column(
                    children: [
                      _DayDot(
                        done: doneDates.contains(_key(day)),
                        isToday: day == base,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        weekdays[day.weekday - 1],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: day == base
                              ? SukunColors.nightNavy
                              : SukunColors.muted,
                          fontWeight: day == base
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (onOpenHistory != null) ...[
            const SizedBox(height: 8),
            Text(
              'বিস্তারিত অগ্রগতি দেখতে চাপুন',
              style: theme.textTheme.bodySmall?.copyWith(
                color: SukunColors.deepTide,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.done, required this.isToday});

  final bool done;
  final bool isToday;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      color: done ? SukunColors.sukunBlue : SukunColors.mist,
      shape: BoxShape.circle,
      border: isToday
          ? Border.all(color: SukunColors.deepTide, width: 2)
          : null,
    ),
    child: done
        ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
        : null,
  );
}

String _bnDigits(int value) {
  const digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  return '$value'.split('').map((d) => digits[int.parse(d)]).join();
}
