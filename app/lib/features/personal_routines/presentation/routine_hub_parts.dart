import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

/// Tabs inside the Routine hub. Today comes first because it is what people
/// open the app for every day.
enum RoutineHubTab { today, myRoutines, progress }

/// Maps the `?tab=` query (and a library `resourceId`) to the first tab.
/// `assigned` was the old "ready routines" tab; those now live inside
/// My Routines, so old links still land in the right place.
RoutineHubTab routineHubInitialTab({String? initialTab, String? resourceId}) {
  if (resourceId != null) return RoutineHubTab.myRoutines;
  return switch (initialTab) {
    'progress' => RoutineHubTab.progress,
    'assigned' || 'routines' || 'mine' => RoutineHubTab.myRoutines,
    _ => RoutineHubTab.today,
  };
}

String routineHubTabLabel(RoutineHubTab tab) => switch (tab) {
  RoutineHubTab.today => 'আজ',
  RoutineHubTab.myRoutines => 'আমার রুটিন',
  RoutineHubTab.progress => 'অগ্রগতি',
};

/// Calm Mist segmented switch, the same pattern as patient detail.
class RoutineHubTabs extends StatelessWidget {
  const RoutineHubTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final RoutineHubTab selected;
  final ValueChanged<RoutineHubTab> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: SukunColors.mist,
      borderRadius: BorderRadius.circular(SukunRadius.control + 2),
    ),
    child: Row(
      children: [
        for (final tab in RoutineHubTab.values)
          Expanded(
            child: Semantics(
              selected: tab == selected,
              button: true,
              child: InkWell(
                key: Key('routine-hub-tab-${tab.name}'),
                borderRadius: BorderRadius.circular(SukunRadius.control - 2),
                onTap: () => onSelected(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 42),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tab == selected ? Colors.white : null,
                    borderRadius: BorderRadius.circular(
                      SukunRadius.control - 2,
                    ),
                    boxShadow: tab == selected
                        ? [
                            BoxShadow(
                              color: SukunColors.nightNavy.withValues(
                                alpha: 0.10,
                              ),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    routineHubTabLabel(tab),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: tab == selected
                          ? SukunColors.nightNavy
                          : SukunColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Human Bangla text for an action's schedule instead of raw database values.
String routineScheduleLabel(Map<String, dynamic> action) {
  final kind = action['schedule_kind'] as String? ?? 'manual';
  final offset = action['prayer_offset_minutes'] as int?;
  switch (kind) {
    case 'fixed':
      final time = action['local_time'] as String?;
      return time != null && time.length >= 5
          ? 'প্রতিদিন ${time.substring(0, 5)}'
          : 'নির্দিষ্ট সময়ে';
    case 'fajr':
      return offset == null ? 'ফজরের পরে' : 'ফজরের $offset মিনিট পরে';
    case 'maghrib':
      return offset == null ? 'মাগরিবের পরে' : 'মাগরিবের $offset মিনিট পরে';
    default:
      return 'নিজে যখন চাই';
  }
}

/// Today's outcome as a short Bangla label and tone. Raw values (`done`,
/// `skipped`) are never shown to people.
(String, SukunStatusTone) routineOutcomeLabel(String? outcome) =>
    switch (outcome) {
      'done' => ('আজ সম্পন্ন', SukunStatusTone.success),
      'skipped' => ('আজ বাদ', SukunStatusTone.neutral),
      _ => ('আজ বাকি', SukunStatusTone.warning),
    };

/// Asks before anything is deleted. Returns true only on an explicit yes.
Future<bool> confirmRoutineDeletion(
  BuildContext context, {
  required String title,
  required bool isRoutine,
}) => showSukunDecisionDialog(
  context: context,
  title: isRoutine ? 'রুটিনটি মুছে ফেলবেন?' : 'করণীয়টি মুছে ফেলবেন?',
  message: isRoutine
      ? '“$title” ও এর সব করণীয় মুছে যাবে। এটি ফেরানো যাবে না।'
      : '“$title” মুছে যাবে। এটি ফেরানো যাবে না।',
  confirmLabel: 'মুছে ফেলুন',
  cancelLabel: 'বাতিল',
  icon: Icons.delete_outline_rounded,
);

/// One personal routine with its actions. All mutations are callbacks so the
/// screen keeps owning data access exactly as before.
class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.routine,
    required this.actions,
    required this.outcomes,
    required this.busy,
    required this.onToggleActive,
    required this.onDeleteRoutine,
    required this.onOpenAction,
    required this.onActionMenu,
    required this.onAddAction,
  });

  final Map<String, dynamic> routine;
  final List<Map<String, dynamic>> actions;
  final Map<String, String> outcomes;
  final bool busy;
  final VoidCallback onToggleActive;
  final VoidCallback onDeleteRoutine;
  final ValueChanged<Map<String, dynamic>> onOpenAction;

  /// value is one of: done, skipped, edit, duplicate, delete.
  final void Function(Map<String, dynamic> action, String value) onActionMenu;
  final VoidCallback onAddAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = routine['is_active'] == true;
    return SukunSurface(
      key: Key('routine-card-${routine['id']}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SukunSpace.lg,
              14,
              SukunSpace.xs,
              SukunSpace.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine['title'].toString(),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SukunStatusPill(
                        label: active ? 'চালু আছে' : 'থামানো আছে',
                        tone: active
                            ? SukunStatusTone.success
                            : SukunStatusTone.neutral,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('routine-menu-${routine['id']}'),
                  tooltip: 'রুটিনের আরও কাজ',
                  enabled: !busy,
                  onSelected: (value) {
                    if (value == 'pause') onToggleActive();
                    if (value == 'delete') onDeleteRoutine();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'pause',
                      child: Text(active ? 'থামান' : 'আবার চালু করুন'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('মুছে ফেলুন'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          for (final action in actions) ...[
            const Divider(height: 1, indent: 16, color: Color(0xFFEEF4F9)),
            _RoutineActionRow(
              action: action,
              outcome: outcomes[action['id']],
              busy: busy,
              onOpen: () => onOpenAction(action),
              onMenu: (value) => onActionMenu(action, value),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SukunSpace.md,
              SukunSpace.xs,
              SukunSpace.md,
              SukunSpace.md,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy ? null : onAddAction,
                icon: const Icon(Icons.add),
                label: const Text('করণীয় যোগ করুন'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineActionRow extends StatelessWidget {
  const _RoutineActionRow({
    required this.action,
    required this.outcome,
    required this.busy,
    required this.onOpen,
    required this.onMenu,
  });

  final Map<String, dynamic> action;
  final String? outcome;
  final bool busy;
  final VoidCallback onOpen;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final (outcomeLabel, outcomeTone) = routineOutcomeLabel(outcome);
    final reminder = action['notification_title']?.toString().trim() ?? '';
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SukunSpace.lg,
          10,
          SukunSpace.xs,
          10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action['title'].toString(),
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reminder.isEmpty
                        ? routineScheduleLabel(action)
                        : '${routineScheduleLabel(action)} · $reminder',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: SukunColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SukunStatusPill(label: outcomeLabel, tone: outcomeTone),
            PopupMenuButton<String>(
              key: Key('routine-action-menu-${action['id']}'),
              tooltip: 'করণীয়ের আরও কাজ',
              enabled: !busy,
              onSelected: onMenu,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'done', child: Text('আজ সম্পন্ন')),
                PopupMenuItem(value: 'skipped', child: Text('আজ বাদ দিন')),
                PopupMenuItem(value: 'edit', child: Text('সম্পাদনা')),
                PopupMenuItem(value: 'duplicate', child: Text('ডুপ্লিকেট')),
                PopupMenuItem(value: 'delete', child: Text('মুছে ফেলুন')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
