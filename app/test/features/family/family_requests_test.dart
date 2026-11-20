import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sukun_life/core/notifications/supabase_notification_inbox_repository.dart';
import 'package:sukun_life/core/notifications/supabase_notification_repository.dart';
import 'package:sukun_life/features/family/data/supabase_family_profiles_repository.dart';
import 'package:sukun_life/features/patient_care/data/completion_queue_store.dart';
import 'package:sukun_life/features/patient_care/data/supabase_patient_care_repository.dart';
import 'package:sukun_life/features/patient_care/data/task_completion_coordinator.dart';
import 'package:sukun_life/features/progress/data/supabase_progress_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records every PostgREST call and answers with canned JSON.
final class _Recorder extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  final List<String> bodies = [];
  final Map<String, Object?> rpcResponses = {};
  final Map<String, Object?> tableResponses = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final body = request is http.Request ? request.body : '';
    bodies.add(body);
    final path = request.url.path;
    Object? result =
        tableResponses[path.replaceFirst('/rest/v1/', '')] ?? <Object?>[];
    if (path.startsWith('/rest/v1/rpc/')) {
      final fn = path.substring('/rest/v1/rpc/'.length);
      result = rpcResponses[fn] ?? <Object?>[];
    }
    final bytes = utf8.encode(jsonEncode(result));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  http.BaseRequest rpc(String fn) =>
      requests.firstWhere((r) => r.url.path == '/rest/v1/rpc/$fn');

  Map<String, dynamic> rpcBody(String fn) =>
      jsonDecode(bodies[requests.indexOf(rpc(fn))]) as Map<String, dynamic>;

  Iterable<http.BaseRequest> table(String name) =>
      requests.where((r) => r.url.path == '/rest/v1/$name');
}

SupabaseClient _client(_Recorder recorder) =>
    SupabaseClient('http://localhost', 'anon-key', httpClient: recorder);

void main() {
  test('my_family_profiles() is called and parsed', () async {
    final recorder = _Recorder()
      ..rpcResponses['my_family_profiles'] = [
        {
          'patient_id': 'p1',
          'full_name': 'Rahim',
          'relationship_label': null,
          'display_order': 0,
          'is_primary': true,
          'family_id': 'f1',
          'family_label': 'Rahim family',
        },
        {
          'patient_id': 'p2',
          'full_name': 'Amina',
          'relationship_label': 'স্ত্রী',
          'display_order': 1,
          'is_primary': false,
          'family_id': 'f1',
          'family_label': 'Rahim family',
        },
      ];
    final profiles = await SupabaseFamilyProfilesRepository(_client(recorder))
        .getProfiles();
    expect(profiles.map((p) => p.patientId), ['p1', 'p2']);
    expect(profiles.first.isPrimary, isTrue);
    expect(profiles.last.relationshipLabel, 'স্ত্রী');
    expect(recorder.rpc('my_family_profiles').method, 'POST');
  });

  test('reminder refresh and device registration pass p_patient_id', () async {
    final recorder = _Recorder();
    final repository = SupabaseNotificationRepository(_client(recorder));

    await repository.getReminderTasks(horizonDays: 7, patientId: 'p-b');
    expect(
      recorder.rpcBody('ensure_patient_reminder_tasks')['p_patient_id'],
      'p-b',
    );
    expect(
      recorder.table('care_plans').single.url.queryParameters['patient_id'],
      'eq.p-b',
    );

    await repository.registerDevice(
      installationId: 'install-1',
      platform: 'android',
      pushToken: 'token',
      timezone: 'Asia/Dhaka',
      patientId: 'p-b',
    );
    final register = recorder.rpcBody('register_notification_device');
    expect(register['p_patient_id'], 'p-b');
    expect(register['p_installation_id'], 'install-1');
  });

  test('single-patient callers omit p_patient_id entirely', () async {
    final recorder = _Recorder();
    final repository = SupabaseNotificationRepository(_client(recorder));
    await repository.getReminderTasks(horizonDays: 7);
    await repository.registerDevice(
      installationId: 'i',
      platform: 'android',
      pushToken: 't',
      timezone: 'Asia/Dhaka',
    );
    expect(
      recorder
          .rpcBody('ensure_patient_reminder_tasks')
          .containsKey('p_patient_id'),
      isFalse,
    );
    expect(
      recorder
          .rpcBody('register_notification_device')
          .containsKey('p_patient_id'),
      isFalse,
    );
    expect(
      recorder
          .table('care_plans')
          .single
          .url
          .queryParameters
          .containsKey('patient_id'),
      isFalse,
    );
  });

  test('progress and inbox only read the selected profile', () async {
    final recorder = _Recorder();
    await SupabaseProgressRepository(
      _client(recorder),
      () async => 'p-b',
    ).getMyProgress(days: 7);
    expect(
      recorder.table('task_instances').single.url.queryParameters['patient_id'],
      'eq.p-b',
    );

    final inboxRecorder = _Recorder();
    await SupabaseNotificationInboxRepository(
      _client(inboxRecorder),
      () async => 'p-b',
    ).getRecentMessages();
    expect(
      inboxRecorder
          .table('notification_events')
          .single
          .url
          .queryParameters['patient_id'],
      'eq.p-b',
    );
  });

  test('Today passes p_patient_id and filters plan, tasks and prescriptions', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final recorder = _Recorder()
      ..tableResponses['care_plans'] = {
        'id': 'plan-b',
        'patient_id': 'p-b',
        'version': 1,
        'name': 'Plan B',
        'start_date': '2026-11-01',
        'status': 'active',
        'created_at': '2026-11-01T00:00:00Z',
      };
    final client = _client(recorder);
    // A signed-in session without any network round trip.
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')).replaceAll('=', '')}.'
        '${base64Url.encode(utf8.encode(jsonEncode({'sub': 'login-1', 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000, 'role': 'authenticated'}))).replaceAll('=', '')}.sig';
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
        'user': {
          'id': 'login-1',
          'aud': 'authenticated',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-11-01T00:00:00Z',
        },
      }),
    );
    final repository = SupabasePatientCareRepository(
      client,
      TaskCompletionCoordinator(
        store: SecureCompletionQueueStore(),
        remote: SupabaseTaskCompletionRemote(client),
      ),
      () async => 'p-b',
    );

    await repository.getToday();
    expect(recorder.rpcBody('ensure_patient_tasks')['p_patient_id'], 'p-b');
    expect(
      recorder.table('care_plans').single.url.queryParameters['patient_id'],
      'eq.p-b',
    );

    expect(
      recorder.table('task_instances').single.url.queryParameters['patient_id'],
      'eq.p-b',
    );

    await repository.getVisiblePrescriptions();
    expect(
      recorder.table('prescriptions').single.url.queryParameters['patient_id'],
      'eq.p-b',
    );
  });
}
