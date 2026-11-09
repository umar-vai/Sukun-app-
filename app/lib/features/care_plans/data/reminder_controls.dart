import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Super Admin reminder controls. Each call is checked and audited in the
/// database; nothing here trusts the UI for permission.
abstract interface class ReminderControls {
  /// Name shown by the phone for one action of a DRAFT care plan.
  Future<void> setDraftNotificationTitle(String actionId, String? title);

  /// Switches one approved action of the patient's live plan on or off
  /// straight away (no new plan version).
  Future<bool> setLivePlanReminder(String actionId, bool enabled);

  /// Switches one action of a routine an admin set for a user.
  Future<bool> setRoutineActionReminder(String actionId, bool enabled);
}

final class SupabaseReminderControls implements ReminderControls {
  const SupabaseReminderControls(this._client);

  final SupabaseClient _client;

  @override
  Future<void> setDraftNotificationTitle(String actionId, String? title) async {
    await _client.rpc(
      'set_draft_action_notification_title',
      params: {'p_action_id': actionId, 'p_notification_title': title},
    );
  }

  @override
  Future<bool> setLivePlanReminder(String actionId, bool enabled) async {
    final result = await _client.rpc(
      'admin_set_plan_action_reminder',
      params: {'p_action_id': actionId, 'p_enabled': enabled},
    );
    return result is bool ? result : enabled;
  }

  @override
  Future<bool> setRoutineActionReminder(String actionId, bool enabled) async {
    final result = await _client.rpc(
      'admin_set_user_routine_action_reminder',
      params: {'p_action_id': actionId, 'p_enabled': enabled},
    );
    return result is bool ? result : enabled;
  }
}

final reminderControlsProvider = Provider<ReminderControls>(
  (ref) => SupabaseReminderControls(Supabase.instance.client),
);

/// Saves a reminder name after an import. A failure only means the phone
/// shows the generic reminder text, so it never blocks the import.
Future<void> saveReminderName(
  WidgetRef ref,
  String actionId,
  String? title,
) async {
  try {
    await ref
        .read(reminderControlsProvider)
        .setDraftNotificationTitle(actionId, title);
  } catch (_) {
    // Generic text is the private fallback.
  }
}
