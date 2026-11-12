import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

/// Distinct calendar colours, so the admin always sees which bath a day has.
Color ghuslColor(GhuslKind kind) => switch (kind) {
  GhuslKind.nazar => const Color(0xFF0A70A8),
  GhuslKind.boroi => const Color(0xFF2F8F6B),
  GhuslKind.detox => const Color(0xFFC2410C),
};

/// Opens the per-person ghusl calendar. Returns the chosen dates per kind,
/// or null when the admin leaves without saving.
Future<Map<GhuslKind, Set<DateTime>>?> showGhuslCalendar(
  BuildContext context, {
  required Map<GhuslKind, Set<DateTime>> initial,
  GhuslKind? focus,
  DateTime? today,
}) => Navigator.of(context).push<Map<GhuslKind, Set<DateTime>>>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) =>
        GhuslCalendarScreen(initial: initial, focus: focus, today: today),
  ),
);

/// One calendar for the three baths (owner request 2026-11-12). Pick a bath,
/// then tap days. A day holds one bath; on a detox day the person sees only
/// the detox bath and its content, every other reminder pauses.
class GhuslCalendarScreen extends StatefulWidget {
  const GhuslCalendarScreen({
    super.key,
    required this.initial,
    this.focus,
    this.today,
  });

  final Map<GhuslKind, Set<DateTime>> initial;
  final GhuslKind? focus;
  final DateTime? today;

  @override
  State<GhuslCalendarScreen> createState() => _GhuslCalendarScreenState();
}

class _GhuslCalendarScreenState extends State<GhuslCalendarScreen> {
  late final DateTime _today = () {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }();
  late final Map<DateTime, GhuslKind> _days = {
    for (final entry in widget.initial.entries)
      for (final date in entry.value)
        if (!_day(date).isBefore(_today)) _day(date): entry.key,
  };
  late GhuslKind _active = widget.focus ?? GhuslKind.nazar;
  late DateTime _month = DateTime(_today.year, _today.month);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _lastDay => _today.add(const Duration(days: 365));

  int _count(GhuslKind kind) => _days.values.where((k) => k == kind).length;

  void _tap(DateTime day) {
    if (day.isBefore(_today) || day.isAfter(_lastDay)) return;
    setState(() {
      if (_days[day] == _active) {
        _days.remove(day);
      } else if (_count(_active) < maxActionDates) {
        _days[day] = _active;
      }
    });
  }

  void _save() {
    Navigator.of(context).pop({
      for (final kind in GhuslKind.values)
        kind: {
          for (final entry in _days.entries)
            if (entry.value == kind) entry.key,
        },
    });
  }

  static const _monthNames = [
    'জানুয়ারি',
    'ফেব্রুয়ারি',
    'মার্চ',
    'এপ্রিল',
    'মে',
    'জুন',
    'জুলাই',
    'আগস্ট',
    'সেপ্টেম্বর',
    'অক্টোবর',
    'নভেম্বর',
    'ডিসেম্বর',
  ];

  // Week starts on Saturday, as in Bangladesh.
  static const _weekdays = [
    'শনি',
    'রবি',
    'সোম',
    'মঙ্গল',
    'বুধ',
    'বৃহঃ',
    'শুক্র',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPrev = _month.isAfter(DateTime(_today.year, _today.month));
    final canNext = DateTime(
      _month.year,
      _month.month + 1,
    ).isBefore(DateTime(_lastDay.year, _lastDay.month + 1));
    return Scaffold(
      appBar: AppBar(
        title: const Text('গোসল ক্যালেন্ডার'),
        actions: [
          TextButton(
            key: const Key('ghusl-calendar-save'),
            onPressed: _save,
            child: const Text('সেভ'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SukunSpace.page,
              SukunSpace.sm,
              SukunSpace.page,
              40,
            ),
            children: [
              for (final kind in GhuslKind.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: SukunSpace.sm),
                  child: _KindTile(
                    kind: kind,
                    count: _count(kind),
                    selected: _active == kind,
                    onTap: () => setState(() => _active = kind),
                  ),
                ),
              const SizedBox(height: SukunSpace.md),
              Row(
                children: [
                  IconButton(
                    tooltip: 'আগের মাস',
                    onPressed: canPrev
                        ? () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month - 1,
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${_monthNames[_month.month - 1]} '
                      '${toBanglaDigits('${_month.year}')}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'পরের মাস',
                    onPressed: canNext
                        ? () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month + 1,
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: SukunSpace.sm),
              _grid(theme),
              if (_count(GhuslKind.detox) > 0) ...[
                const SizedBox(height: SukunSpace.lg),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: ghuslColor(GhuslKind.detox),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ডিটক্সের দিনে অন্য সব আমল ও রিমাইন্ডার বন্ধ থাকবে',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(ThemeData theme) {
    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // DateTime.weekday: Mon=1..Sun=7. Column 0 is Saturday.
    final lead = (first.weekday + 1) % 7;
    final cells = <Widget>[
      for (final name in _weekdays)
        Center(
          child: Text(
            name,
            style: theme.textTheme.labelSmall?.copyWith(
              color: SukunColors.muted,
            ),
          ),
        ),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _dayCell(DateTime(_month.year, _month.month, d), theme),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: cells,
    );
  }

  Widget _dayCell(DateTime day, ThemeData theme) {
    final kind = _days[day];
    final disabled = day.isBefore(_today) || day.isAfter(_lastDay);
    final isToday = day == _today;
    final color = kind == null ? null : ghuslColor(kind);
    return Semantics(
      button: !disabled,
      selected: kind != null,
      label: kind?.label,
      child: InkWell(
        key: Key('ghusl-day-${isoDate(day)}'),
        onTap: disabled ? null : () => _tap(day),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: isToday && color == null
                ? Border.all(color: SukunColors.deepTide, width: 1.5)
                : null,
          ),
          child: Text(
            toBanglaDigits('${day.day}'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color != null
                  ? Colors.white
                  : disabled
                  ? SukunColors.muted.withValues(alpha: 0.45)
                  : null,
              fontWeight: color != null || isToday
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final GhuslKind kind;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ghuslColor(kind);
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? color.withValues(alpha: 0.1)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SukunRadius.tile),
        side: BorderSide(
          color: selected ? color : SukunColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        key: Key('ghusl-kind-${kind.databaseValue}'),
        borderRadius: BorderRadius.circular(SukunRadius.tile),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  kind.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${toBanglaDigits('$count')} দিন',
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.edit_calendar_rounded, color: color, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
