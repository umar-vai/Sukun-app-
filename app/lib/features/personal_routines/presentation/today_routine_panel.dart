import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          key: const Key('today-routine-overview'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D2B45), Color(0xFF0A70A8)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'আজকের রুটিন',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'প্রতিটি আমল সম্পন্ন হলে এখানেই চিহ্নিত করুন',
                style: TextStyle(color: Color(0xFFDAF4FF)),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 310;
                  final ring = SizedBox.square(
                    dimension: 148,
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
                                strokeWidth: 11,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF8EDCFA),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$percentage%',
                                  key: const Key('today-routine-percentage'),
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const Text(
                                  'সম্পন্ন',
                                  style: TextStyle(color: Color(0xFFDAF4FF)),
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
                        '${summary.completed} টি সম্পন্ন',
                        key: const Key('today-routine-completed-count'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        '${summary.remaining} টি বাকি',
                        key: const Key('today-routine-remaining-count'),
                        style: const TextStyle(
                          color: Color(0xFFDAF4FF),
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'মোট ${summary.total} টি সক্রিয় করণীয়',
                        style: const TextStyle(color: Color(0xFFDAF4FF)),
                      ),
                    ],
                  );
                  return narrow
                      ? Column(
                          children: [
                            ring,
                            const SizedBox(height: 20),
                            counters,
                          ],
                        )
                      : Row(
                          children: [
                            ring,
                            const SizedBox(width: 24),
                            Expanded(child: counters),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'আজকের করণীয়',
          style: theme.textTheme.titleLarge?.copyWith(
            color: SukunColors.nightNavy,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          summary.total == 0
              ? 'কোনো সক্রিয় রুটিন নেই। আমার রুটিন থেকে করণীয় যোগ করুন।'
              : 'যেগুলো বাকি আছে সেগুলো আগে দেখানো হচ্ছে।',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        for (final action in [
          ...activeActions.where((a) => outcomes[a['id']] != 'done'),
          ...activeActions.where((a) => outcomes[a['id']] == 'done'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
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
        if (onOpenPatientToday != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_turned_in_outlined),
              title: const Text('সুকুন লাইফের নির্ধারিত আমল'),
              subtitle: const Text(
                'আপনার অনুমোদিত চিকিৎসা-পরিকল্পনার আজকের কাজ',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenPatientToday,
            ),
          ),
        if (onOpenHistory != null)
          TextButton.icon(
            onPressed: onOpenHistory,
            icon: const Icon(Icons.history_rounded),
            label: const Text('আগের দিনের অগ্রগতি দেখুন'),
          ),
        const SizedBox(height: 10),
        Text(
          'এই অগ্রগতি শুধু নিজের সম্পন্ন করা রুটিনের হিসাব; চিকিৎসার ফলাফল নয়।',
          style: theme.textTheme.bodySmall,
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
  Widget build(BuildContext context) => Card(
    key: Key('today-action-${action['id']}'),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: done ? const Color(0xFF8EDCFA) : Colors.black12),
    ),
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
                      style: Theme.of(context).textTheme.bodySmall,
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
