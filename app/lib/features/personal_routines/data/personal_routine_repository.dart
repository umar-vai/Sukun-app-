import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Personal routines never read or mutate clinician-approved patient plans.
final class PersonalRoutineRepository {
  const PersonalRoutineRepository(this.client);

  final SupabaseClient client;

  String get ownerId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to save personal routines.');
    return id;
  }

  Future<List<Map<String, dynamic>>> listRoutines() async {
    final rows = await client
        .from('personal_routines')
        .select('id,title,is_active,created_at')
        .order('created_at', ascending: true);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> listActions() async {
    final rows = await client
        .from('personal_routine_actions')
        .select(
          'id,routine_id,title,notification_title,notes,resource_provider,'
          'content_item_id,external_resource_ref,schedule_kind,local_time,'
          'prayer_offset_minutes,timezone_name,prayer_city,'
          'prayer_latitude,prayer_longitude,prayer_method,is_active',
        )
        .order('created_at', ascending: true);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>> createRoutine(String title) async {
    final result = await client
        .from('personal_routines')
        .insert({'owner_user_id': ownerId, 'title': title.trim()})
        .select('id,title,is_active,created_at')
        .single();
    return Map<String, dynamic>.from(result);
  }

  Future<void> deleteRoutine(String id) async {
    await client.from('personal_routines').delete().eq('id', id);
  }

  Future<void> setRoutineActive(String id, bool active) async {
    await client
        .from('personal_routines')
        .update({
          'is_active': active,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> saveAction({
    required String routineId,
    String? actionId,
    required String title,
    required String notificationTitle,
    String? contentItemId,
    required String scheduleKind,
    required int offsetMinutes,
    String? fixedTime,
    String? timezoneName,
    String? city,
    double? latitude,
    double? longitude,
    String? prayerMethod,
    bool isActive = true,
  }) async {
    final payload = <String, dynamic>{
      'owner_user_id': ownerId,
      'routine_id': routineId,
      'title': title.trim(),
      'notification_title': notificationTitle.trim(),
      'resource_provider': contentItemId == null ? 'manual' : 'cms',
      'content_item_id': contentItemId,
      'external_resource_ref': null,
      'schedule_kind': scheduleKind,
      'local_time': scheduleKind == 'fixed' ? fixedTime : null,
      'prayer_offset_minutes': offsetMinutes,
      'timezone_name': timezoneName ?? 'UTC',
      'prayer_city': city,
      'prayer_latitude': latitude,
      'prayer_longitude': longitude,
      'prayer_method': prayerMethod,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (actionId == null) {
      await client.from('personal_routine_actions').insert(payload);
    } else {
      payload.remove('owner_user_id');
      payload.remove('routine_id');
      await client
          .from('personal_routine_actions')
          .update(payload)
          .eq('id', actionId);
    }
  }

  Future<void> duplicateAction(Map<String, dynamic> action) async {
    final payload = Map<String, dynamic>.from(action)
      ..remove('id')
      ..['owner_user_id'] = ownerId
      ..['created_at'] = DateTime.now().toUtc().toIso8601String()
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String()
      ..['is_active'] = false;
    await client.from('personal_routine_actions').insert(payload);
  }

  Future<void> deleteAction(String id) async {
    await client.from('personal_routine_actions').delete().eq('id', id);
  }

  Future<void> recordOutcome({
    required String actionId,
    required DateTime localDate,
    required String outcome,
  }) async {
    final day = DateFormat('yyyy-MM-dd').format(localDate);
    await client.from('personal_routine_progress').upsert({
      'action_id': actionId,
      'owner_user_id': ownerId,
      'local_date': day,
      'outcome': outcome,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'action_id,local_date');
  }

  Future<Map<String, String>> todaysOutcomes(DateTime date) async {
    final day = DateFormat('yyyy-MM-dd').format(date);
    final rows = await client
        .from('personal_routine_progress')
        .select('action_id,outcome')
        .eq('local_date', day);
    return {
      for (final row in rows)
        row['action_id'] as String: row['outcome'] as String,
    };
  }
}
