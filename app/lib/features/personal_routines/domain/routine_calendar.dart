/// Ghusl calendar rules for routine steps (owner request 2026-11-12).
///
/// A step with `active_dates` runs only on those local dates; without it the
/// step runs every day. On a date where any active step is a detox bath
/// (`ghusl_kind = 'detox'`), every other step pauses: the person sees and is
/// reminded of only the detox bath and its linked content.
library;

String _key(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Set<String> _dates(Map<String, dynamic> action) {
  final raw = action['active_dates'];
  if (raw is! List) return const {};
  return {
    for (final value in raw)
      if (value != null) value.toString().substring(0, 10),
  };
}

bool _isDetox(Map<String, dynamic> action) => action['ghusl_kind'] == 'detox';

/// Local dates (YYYY-MM-DD) that are detox days among [actions].
Set<String> routineDetoxDates(Iterable<Map<String, dynamic>> actions) => {
  for (final action in actions)
    if (_isDetox(action) && action['is_active'] == true) ..._dates(action),
};

/// Whether [action] runs on [date], given the person's [detoxDates].
bool routineActionRunsOn(
  Map<String, dynamic> action,
  DateTime date, {
  required Set<String> detoxDates,
}) {
  final key = _key(date);
  final dates = _dates(action);
  if (action['active_dates'] is List && !dates.contains(key)) return false;
  if (detoxDates.contains(key) && !_isDetox(action)) return false;
  return true;
}
