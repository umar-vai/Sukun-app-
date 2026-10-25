import 'package:intl/intl.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_action_resource_selection.dart';
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

  /// Admin-published templates are public to signed-in Members/Patients only.
  /// Drafts and unpublished steps remain protected by Supabase RLS.
  Future<List<Map<String, dynamic>>> listPublishedTemplates() async {
    final rows = await client
        .from('routine_templates')
        .select(
          'id,title,description,status,routine_template_steps(id,title,sort_order)',
        )
        .eq('status', 'published')
        .order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// The owner-private routine and all its steps are created atomically by an
  /// invoker-security RPC. No clinic/patient plan is modified or copied.
  Future<String> adoptPublishedTemplate(String templateId) async {
    final result = await client.rpc(
      'adopt_published_routine_template',
      params: {'p_template_id': templateId},
    );
    return result as String;
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

  Future<String> saveAction({
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
      final created = await client
          .from('personal_routine_actions')
          .insert(payload)
          .select('id')
          .single();
      return created['id'] as String;
    } else {
      payload.remove('owner_user_id');
      payload.remove('routine_id');
      await client
          .from('personal_routine_actions')
          .update(payload)
          .eq('id', actionId);
      return actionId;
    }
  }

  /// Ordered resource references; RLS filters out every other owner's rows.
  Future<List<Map<String, dynamic>>> listActionResources(
    String actionId,
  ) async {
    final rows = await client
        .from('personal_routine_action_resources')
        .select(
          'id,action_id,provider,content_item_id,external_resource_ref,sort_order,content_items(id,title,title_bn,type,status,visibility,media_source_type,media_url)',
        )
        .eq('action_id', actionId)
        .order('sort_order', ascending: true);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// The SECURITY INVOKER RPC applies the whole ordered selection atomically.
  /// Only published, public CMS items can be persisted by normal users.
  Future<void> replaceActionResources({
    required String actionId,
    required List<PersonalActionResourceSelection> orderedResources,
  }) async {
    PersonalActionResourceSelection.validate(orderedResources);
    await client.rpc(
      'replace_personal_action_resources',
      params: {
        'p_action_id': actionId,
        'p_resources': [for (final item in orderedResources) item.rpcValue],
      },
    );
  }

  Future<Map<String, dynamic>?> getAction(String actionId) async {
    final row = await client
        .from('personal_routine_actions')
        .select(
          'id,routine_id,title,notification_title,content_item_id,resource_provider,is_active',
        )
        .eq('id', actionId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> duplicateAction(Map<String, dynamic> action) async {
    final sourceId = action['id'] as String;
    final links = await listActionResources(sourceId);
    final payload = Map<String, dynamic>.from(action)
      ..remove('id')
      ..['owner_user_id'] = ownerId
      ..['created_at'] = DateTime.now().toUtc().toIso8601String()
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String()
      ..['is_active'] = false;
    final newRow = await client
        .from('personal_routine_actions')
        .insert(payload)
        .select('id')
        .single();
    final newId = newRow['id'] as String;
    try {
      if (links.isNotEmpty) {
        await client.rpc(
          'replace_personal_action_resources',
          params: {
            'p_action_id': newId,
            'p_resources': [
              for (final link in links)
                if (link['provider'] == 'cms')
                  {
                    'provider': 'cms',
                    'content_item_id': link['content_item_id'],
                  }
                else
                  {
                    'provider': link['provider'],
                    'external_resource_ref': link['external_resource_ref'],
                  },
            ],
          },
        );
      }
    } catch (_) {
      // Do not leave a half-duplicated active-looking action if any reference
      // was unpublished or rejected by RLS while copying.
      await client.from('personal_routine_actions').delete().eq('id', newId);
      rethrow;
    }
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

  /// Read only this signed-in owner's check-ins; both Member and Patient use it.
  /// These events are not a clinical adherence or diagnosis metric.
  Future<List<Map<String, dynamic>>> listProgress({int days = 7}) async {
    if (days != 7 && days != 30) {
      throw ArgumentError.value(days, 'days', 'Only 7 or 30 days supported');
    }
    final start = DateTime.now().subtract(Duration(days: days - 1));
    final startDate = DateFormat('yyyy-MM-dd').format(start);
    final rows = await client
        .from('personal_routine_progress')
        .select('action_id,local_date,outcome')
        .eq('owner_user_id', ownerId)
        .gte('local_date', startDate)
        .order('local_date', ascending: false)
        .limit(1000);
    final actions = await client
        .from('personal_routine_actions')
        .select('id,title')
        .eq('owner_user_id', ownerId);
    final titles = <String, String>{
      for (final action in actions)
        action['id'] as String: action['title'] as String,
    };
    return rows.map((row) {
      final result = Map<String, dynamic>.from(row);
      result['title'] = titles[row['action_id']] ?? 'করণীয়';
      return result;
    }).toList();
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
