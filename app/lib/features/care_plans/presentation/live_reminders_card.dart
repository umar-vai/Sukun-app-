import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

/// One running reminder an admin can switch on or off.
final class LiveReminder {
  const LiveReminder({
    required this.id,
    required this.title,
    required this.enabled,
    this.notificationTitle,
    this.time,
    this.canSwitchOn = true,
  });

  /// From an approved action of the patient's live care plan.
  factory LiveReminder.fromPlanAction(PlanAction action) {
    final exact = action.exactTime;
    return LiveReminder(
      id: action.id,
      title: action.title,
      enabled: action.reminderEnabled,
      notificationTitle: action.notificationTitle,
      time: exact == null ? null : ReminderClock(exact.hour, exact.minute),
      // The database refuses a reminder without an approved exact time.
      canSwitchOn: exact != null,
    );
  }

  /// From `admin_get_user_routine_overview` (admin-set routines only).
  static LiveReminder? fromRoutineAction(Map<String, dynamic> action) {
    final id = action['id'];
    final title = action['title'];
    if (id is! String || title is! String) return null;
    return LiveReminder(
      id: id,
      title: title,
      enabled: action['is_active'] != false,
      notificationTitle: action['notification_title'] as String?,
      time: _parseClock(action['local_time']),
    );
  }

  final String id;
  final String title;
  final bool enabled;
  final String? notificationTitle;
  final ReminderClock? time;
  final bool canSwitchOn;

  LiveReminder copyWith({required bool enabled}) => LiveReminder(
    id: id,
    title: title,
    enabled: enabled,
    notificationTitle: notificationTitle,
    time: time,
    canSwitchOn: canSwitchOn,
  );
}

ReminderClock? _parseClock(Object? value) {
  if (value is! String) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return ReminderClock(hour, minute);
}

/// Running reminders with an on/off switch each. A switch saves at once
/// (audited on the server); on failure it flips back and says so.
class LiveRemindersCard extends StatefulWidget {
  const LiveRemindersCard({
    super.key,
    required this.load,
    required this.onToggle,
    this.emptyText = 'এখন কোনো চলমান রিমাইন্ডার নেই।',
  });

  final Future<List<LiveReminder>> Function() load;

  /// Returns the saved state.
  final Future<bool> Function(String id, bool enabled) onToggle;
  final String emptyText;

  @override
  State<LiveRemindersCard> createState() => _LiveRemindersCardState();
}

class _LiveRemindersCardState extends State<LiveRemindersCard> {
  List<LiveReminder>? _items;
  bool _failed = false;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _failed = false);
    try {
      final items = await widget.load();
      items.sort((a, b) {
        final left = a.time, right = b.time;
        if (left == null || right == null) {
          return left == null ? (right == null ? 0 : 1) : -1;
        }
        return left.compareTo(right);
      });
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _toggle(int index, bool enabled) async {
    final items = _items;
    if (items == null) return;
    final current = items[index];
    if (_saving.contains(current.id)) return;
    setState(() {
      _saving.add(current.id);
      items[index] = current.copyWith(enabled: enabled);
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await widget.onToggle(current.id, enabled);
      if (!mounted) return;
      setState(() => items[index] = current.copyWith(enabled: saved));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? '“${current.title}” রিমাইন্ডার চালু হয়েছে।'
                : '“${current.title}” রিমাইন্ডার বন্ধ হয়েছে।',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => items[index] = current);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('বদলানো যায়নি। সংযোগ দেখে আবার চেষ্টা করুন।'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(current.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items;
    if (_failed) {
      return SukunSurface(
        padding: const EdgeInsets.all(SukunSpace.lg),
        child: Row(
          children: [
            const Expanded(child: Text('রিমাইন্ডারের তালিকা আনা যায়নি।')),
            TextButton(onPressed: _reload, child: const Text('আবার চেষ্টা')),
          ],
        ),
      );
    }
    if (items == null) {
      return const Padding(
        padding: EdgeInsets.all(SukunSpace.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      return SukunSurface(
        tone: SukunSurfaceTone.soft,
        showBorder: false,
        padding: const EdgeInsets.all(SukunSpace.lg),
        child: Text(widget.emptyText),
      );
    }
    final on = items.where((item) => item.enabled).length;
    return SukunSurface(
      padding: const EdgeInsets.symmetric(vertical: SukunSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SukunSpace.lg,
              SukunSpace.xs,
              SukunSpace.lg,
              SukunSpace.xs,
            ),
            child: Text(
              '${toBanglaDigits('${items.length}')}টির মধ্যে '
              '${toBanglaDigits('$on')}টি চালু · সুইচ চাপলেই সাথে সাথে সেভ হয়',
              style: theme.textTheme.bodySmall?.copyWith(
                color: SukunColors.muted,
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            SwitchListTile.adaptive(
              key: Key('live-reminder-${items[i].id}'),
              value: items[i].enabled,
              onChanged:
                  _saving.contains(items[i].id) ||
                      (!items[i].enabled && !items[i].canSwitchOn)
                  ? null
                  : (value) => _toggle(i, value),
              secondary: Icon(
                items[i].enabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: items[i].enabled
                    ? theme.colorScheme.primary
                    : SukunColors.muted,
              ),
              title: Text(
                items[i].title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                [
                  items[i].time?.label ?? 'সময় নির্ধারিত নেই',
                  if (items[i].notificationTitle != null)
                    'নোটিফিকেশন: ${items[i].notificationTitle}',
                ].join(' · '),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
