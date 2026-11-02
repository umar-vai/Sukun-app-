// Preview-only, in-browser stand-in for the Supabase HTTP APIs.
//
// It lets the real app code (repositories, screens, auth flow) run unchanged
// against sample data so that visual changes to signed-in screens can be
// reviewed without access to the real Supabase project. Nothing here is
// used by the Android/iOS or production web builds.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'package:sukun_life/preview/preview_seed_data.g.dart';

typedef _Row = Map<String, dynamic>;

class PreviewAccount {
  const PreviewAccount(this.userId, this.email, this.label);
  final String userId;
  final String email;
  final String label;
}

const previewAdmin = PreviewAccount(
  '00000000-0000-4000-8000-0000000000a1',
  'admin@preview.sukun',
  'Super Admin',
);
const previewPatient = PreviewAccount(
  '00000000-0000-4000-8000-0000000000b1',
  'patient@preview.sukun',
  'রোগী',
);
const previewMember = PreviewAccount(
  '00000000-0000-4000-8000-0000000000c1',
  'member@preview.sukun',
  'সদস্য',
);
const previewAccounts = [previewPatient, previewAdmin, previewMember];

class _ForeignKey {
  _ForeignKey(this.table, this.columns, this.refTable, this.refColumns);
  final String table;
  final List<String> columns;
  final String refTable;
  final List<String> refColumns;
}

class _Problem implements Exception {
  _Problem(this.status, this.message);
  final int status;
  final String message;
  final String code = 'PREVIEW';
}

/// In-memory database plus PostgREST/GoTrue/Functions emulation.
class PreviewBackend {
  PreviewBackend._() {
    final decoded = jsonDecode(previewSeedJson) as Map<String, dynamic>;
    final saved = _loadSaved();
    for (final entry
        in (saved ?? decoded['tables'] as Map<String, dynamic>).entries) {
      tables[entry.key] = [
        for (final row in entry.value as List) Map<String, dynamic>.from(row),
      ];
    }
    for (final fk in decoded['foreignKeys'] as List) {
      final map = fk as Map<String, dynamic>;
      _fks.add(
        _ForeignKey(
          map['table'] as String,
          List<String>.from(map['columns'] as List),
          map['refTable'] as String,
          List<String>.from(map['refColumns'] as List),
        ),
      );
    }
    for (final entry in (decoded['columns'] as Map<String, dynamic>).entries) {
      _columns[entry.key] = [
        for (final c in entry.value as List) Map<String, dynamic>.from(c),
      ];
    }
    if (saved == null) _generateHistory();
  }

  static const _storageKey = 'sukun-preview-db-v1';

  static Map<String, dynamic>? _loadSaved() {
    try {
      final raw = web.window.localStorage.getItem(_storageKey);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  Timer? _saveTimer;

  /// Keeps sample-data edits across page reloads in this browser only.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      try {
        web.window.localStorage.setItem(_storageKey, jsonEncode(tables));
      } on Object {
        // Storage can be unavailable (private mode); edits stay in memory.
      }
    });
  }

  /// Restores the original sample data and reloads the page.
  static void resetSampleData() {
    try {
      web.window.localStorage.removeItem(_storageKey);
      for (var i = web.window.localStorage.length - 1; i >= 0; i--) {
        final key = web.window.localStorage.key(i);
        if (key != null && key.startsWith('sb-')) {
          web.window.localStorage.removeItem(key);
        }
      }
    } on Object {
      // Ignore; reload still resets the in-memory copy.
    }
    web.window.location.reload();
  }

  static final PreviewBackend instance = PreviewBackend._();

  final Map<String, List<_Row>> tables = {};
  final List<_ForeignKey> _fks = [];
  final Map<String, List<_Row>> _columns = {};
  final Random _random = Random(7);

  static bool debug = const bool.fromEnvironment('PREVIEW_DEBUG');
  static void _log(String message) {
    // ignore: avoid_print
    if (debug) print('[preview] $message');
  }

  // ---------------------------------------------------------------- helpers

  List<_Row> table(String name) => tables.putIfAbsent(name, () => []);

  static String uuid() {
    final r = Random();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
  }

  static String nowIso() => DateTime.now().toUtc().toIso8601String();

  static String dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  _Row? _byId(String tableName, Object? id) {
    if (id == null) return null;
    for (final row in table(tableName)) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  String? _patientIdForUser(String? userId) {
    for (final p in table('patients')) {
      if (p['user_id'] == userId) return p['id'] as String;
    }
    return null;
  }

  /// Fills a few days of past task history so progress screens have data.
  void _generateHistory() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final offset = now.timeZoneOffset.inMinutes;
    final statuses = ['completed', 'completed', 'completed', 'skipped', 'missed'];
    for (final plan in table('care_plans').where((p) => p['status'] == 'active')) {
      final actions = table('plan_actions')
          .where((a) =>
              a['care_plan_id'] == plan['id'] && a['review_status'] == 'approved')
          .toList();
      for (var back = 6; back >= 1; back--) {
        final day = today.subtract(Duration(days: back));
        for (final action in actions) {
          final status = statuses[_random.nextInt(statuses.length)];
          final scheduled = _scheduledAt(day, action);
          table('task_instances').add({
            'id': uuid(),
            'plan_action_id': action['id'],
            'patient_id': plan['patient_id'],
            'scheduled_at': scheduled,
            'status': status,
            'completed_at': status == 'completed' ? scheduled : null,
            'snoozed_until': null,
            'skip_reason': status == 'skipped' ? 'সময় পাইনি' : null,
            'created_at': scheduled,
            'updated_at': scheduled,
            'occurrence_date': dateOnly(day),
            'timezone_offset_minutes': offset,
          });
        }
      }
    }
    for (final action in table('personal_routine_actions')) {
      for (var back = 6; back >= 1; back--) {
        if (_random.nextInt(4) == 0) continue;
        final day = today.subtract(Duration(days: back));
        table('personal_routine_progress').add({
          'id': uuid(),
          'action_id': action['id'],
          'owner_user_id': action['owner_user_id'],
          'local_date': dateOnly(day),
          'outcome': _random.nextInt(5) == 0 ? 'skipped' : 'done',
          'occurred_at': day.add(const Duration(hours: 9)).toUtc().toIso8601String(),
        });
      }
    }
  }

  String? _scheduledAt(DateTime day, _Row action) {
    final time = action['exact_time'] as String?;
    if (time == null) return null;
    final parts = time.split(':');
    return DateTime(day.year, day.month, day.day, int.parse(parts[0]),
            int.parse(parts[1]))
        .toUtc()
        .toIso8601String();
  }

  _Row _withDefaults(String tableName, _Row input, String? userId) {
    final row = <String, dynamic>{};
    for (final column in _columns[tableName] ?? const <_Row>[]) {
      final name = column['name'] as String;
      final def = column['default'] as String?;
      Object? value;
      if (def == null) {
        value = null;
      } else if (def.contains('gen_random_uuid')) {
        value = uuid();
      } else if (def.contains('now()')) {
        value = nowIso();
      } else if (def.contains('CURRENT_DATE')) {
        value = dateOnly(DateTime.now());
      } else if (def.contains('auth.uid()')) {
        value = userId;
      } else if (def == 'true' || def == 'false') {
        value = def == 'true';
      } else if (RegExp(r'^-?\d+$').hasMatch(def)) {
        value = int.parse(def);
      } else if (def.startsWith("'")) {
        final end = def.indexOf("'", 1);
        final raw = def.substring(1, end);
        value = def.contains('::jsonb') ? jsonDecode(raw) : raw;
      }
      row[name] = value;
    }
    row.addAll(input);
    return row;
  }

  _Row _insert(String tableName, _Row input, String? userId) {
    final row = _withDefaults(tableName, input, userId);
    table(tableName).add(row);
    return row;
  }

  // ------------------------------------------------------- row visibility

  String? _currentUser;

  bool _isAdmin(String? userId) => table('user_roles')
      .any((r) => r['user_id'] == userId && r['role'] == 'super_admin');

  /// Rough stand-in for the database RLS policies, so each demo role only
  /// sees what the real backend would let it see.
  bool _visible(String tableName, _Row row) {
    final userId = _currentUser;
    if (_isAdmin(userId)) return true;
    final patientId = _patientIdForUser(userId);
    bool ownPlan(Object? planId) {
      final plan = _byId('care_plans', planId);
      return plan != null &&
          plan['patient_id'] == patientId &&
          plan['status'] != 'draft' &&
          plan['status'] != 'archived';
    }

    switch (tableName) {
      case 'content_items':
        if (row['status'] != 'published') return false;
        final visibility = row['visibility'];
        return visibility == 'public' ||
            (patientId != null &&
                (visibility == 'patient_only' || visibility == 'assigned_only'));
      case 'content_categories':
        return row['is_active'] == true;
      case 'patients':
        return row['id'] == patientId;
      case 'prescriptions':
        return row['patient_id'] == patientId && row['visibility'] == 'patient';
      case 'care_plans':
        return patientId != null && ownPlan(row['id']);
      case 'plan_actions':
        return ownPlan(row['care_plan_id']) && row['review_status'] == 'approved';
      case 'plan_action_resources':
      case 'plan_action_quran_surahs':
        final action = _byId('plan_actions', row['plan_action_id']);
        return action != null && ownPlan(action['care_plan_id']);
      case 'task_instances':
      case 'task_completions':
      case 'notification_events':
      case 'notification_devices':
        return patientId != null && row['patient_id'] == patientId;
      case 'profiles':
        return row['id'] == userId;
      case 'user_roles':
        return row['user_id'] == userId;
      case 'universal_announcements':
        return row['status'] == 'published';
      case 'routine_templates':
        return row['status'] == 'published';
      case 'routine_template_steps':
      case 'content_collection_items':
      case 'content_collections':
        return true;
      default:
        if (row.containsKey('owner_user_id')) return row['owner_user_id'] == userId;
        if (row.containsKey('user_id')) return row['user_id'] == userId;
        return false;
    }
  }

  List<_Row> visibleRows(String tableName) =>
      table(tableName).where((r) => _visible(tableName, r)).toList();

  // --------------------------------------------------------------- dispatch

  Future<http.StreamedResponse> handle(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    final path = request.url.path;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final userId = _userFromAuthHeader(request.headers);
      _currentUser = userId;
      _log('${request.method} ${request.url} user=$userId body=$body');
      if (request.method != 'GET' &&
          request.method != 'HEAD' &&
          !path.startsWith('/auth/')) {
        _scheduleSave();
      }
      if (path.startsWith('/auth/v1/')) {
        return _auth(request, path.substring('/auth/v1/'.length), body);
      }
      if (path.startsWith('/rest/v1/rpc/')) {
        final fn = path.substring('/rest/v1/rpc/'.length);
        final params = body.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(body) as Map);
        final result = _rpc(fn, params, userId);
        return _json(200, result);
      }
      if (path.startsWith('/rest/v1/')) {
        return _rest(request, path.substring('/rest/v1/'.length), body, userId);
      }
      if (path.startsWith('/functions/v1/')) {
        final fn = path.substring('/functions/v1/'.length);
        final params = body.isEmpty ? null : jsonDecode(body);
        return _function(fn, params, userId);
      }
      if (path.startsWith('/storage/v1/')) {
        return _json(200, request.method == 'GET' ? [] : {'Key': 'preview'});
      }
      return _json(404, {'message': 'Not available in preview'});
    } on _Problem catch (problem) {
      _log('${request.method} ${request.url} -> ${problem.status} ${problem.message}');
      return _json(problem.status, {
        'message': problem.message,
        'code': problem.code,
        'details': null,
        'hint': null,
      });
    } on Object catch (error, stack) {
      _log('${request.method} ${request.url} -> CRASH $error\n$stack');
      return _json(500, {'message': 'Preview backend error: $error', 'code': 'PREVIEW'});
    }
  }

  http.StreamedResponse _json(
    int status,
    Object? value, {
    Map<String, String> headers = const {},
  }) {
    final bytes = value == null && status == 204
        ? <int>[]
        : utf8.encode(jsonEncode(value));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      headers: {'content-type': 'application/json; charset=utf-8', ...headers},
    );
  }

  // ------------------------------------------------------------------ auth

  String? _userFromAuthHeader(Map<String, String> headers) {
    final auth = headers['Authorization'] ?? headers['authorization'];
    if (auth == null || !auth.startsWith('Bearer ')) return null;
    final token = auth.substring(7);
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      if (payload['role'] != 'authenticated') return null;
      return payload['sub'] as String?;
    } on Object {
      return null;
    }
  }

  PreviewAccount? _account({String? email, String? userId}) {
    for (final account in previewAccounts) {
      if (account.email == email || account.userId == userId) return account;
    }
    return null;
  }

  _Row _user(PreviewAccount account) => {
        'id': account.userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': account.email,
        'email_confirmed_at': '2026-01-01T00:00:00Z',
        'phone': '',
        'app_metadata': {'provider': 'email', 'providers': ['email']},
        'user_metadata': <String, dynamic>{},
        'identities': <dynamic>[],
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': nowIso(),
      };

  _Row _session(PreviewAccount account) {
    final exp = DateTime.now().add(const Duration(hours: 12));
    final expSeconds = exp.millisecondsSinceEpoch ~/ 1000;
    String b64(Object v) =>
        base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
    final token = '${b64({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${b64({
          'sub': account.userId,
          'email': account.email,
          'role': 'authenticated',
          'aud': 'authenticated',
          'exp': expSeconds,
          'iat': expSeconds - 43200,
          'session_id': 'preview',
        })}.preview';
    return {
      'access_token': token,
      'token_type': 'bearer',
      'expires_in': 43200,
      'expires_at': expSeconds,
      'refresh_token': 'preview-refresh-${account.userId}',
      'user': _user(account),
    };
  }

  http.StreamedResponse _auth(http.BaseRequest request, String path, String body) {
    final params = body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(body) as Map);
    if (path == 'token') {
      final grant = request.url.queryParameters['grant_type'];
      PreviewAccount? account;
      if (grant == 'password') {
        account = _account(email: (params['email'] as String?)?.trim().toLowerCase());
      } else if (grant == 'refresh_token') {
        final token = params['refresh_token'] as String? ?? '';
        account = _account(userId: token.replaceFirst('preview-refresh-', ''));
      }
      if (account == null) {
        return _json(400, {
          'error': 'invalid_grant',
          'error_description': 'Invalid login credentials',
          'code': 'invalid_credentials',
          'msg': 'Invalid login credentials',
        });
      }
      return _json(200, _session(account));
    }
    if (path == 'user') {
      final userId = _userFromAuthHeader(request.headers);
      final account = _account(userId: userId);
      if (account == null) return _json(401, {'msg': 'not signed in'});
      return _json(200, _user(account));
    }
    if (path == 'logout') return _json(204, null);
    return _json(200, <String, dynamic>{});
  }

  // ------------------------------------------------------------- functions

  http.StreamedResponse _function(String name, Object? params, String? userId) {
    final body = params is Map ? Map<String, dynamic>.from(params) : <String, dynamic>{};
    switch (name) {
      case 'patient-sign-in':
        final identifier = (body['identifier'] as String? ?? '').trim().toUpperCase();
        final patient = table('patients')
            .where((p) => p['patient_code'] == identifier && p['user_id'] != null)
            .firstOrNull;
        if (patient == null) {
          return _json(400, {'message': 'Patient ID or password is incorrect.'});
        }
        final account = _account(userId: patient['user_id'] as String);
        return _json(200, {'refresh_token': 'preview-refresh-${account!.userId}'});
      case 'admin-create-patient':
        final patient = _insert('patients', {
          'patient_code':
              'SL-${1000 + table('patients').length + 1}',
          'full_name': body['full_name'] ?? body['fullName'] ?? 'নতুন রোগী',
          'phone': body['phone'],
          'created_by': userId,
        }, userId);
        return _json(200, {
          'patient': patient,
          'patient_id': patient['id'],
          'patient_code': patient['patient_code'],
          'temporary_password': 'preview-1234',
        });
      case 'prescription-to-actions':
      case 'prescription-document-to-actions':
        return _json(503, {
          'message': 'প্রিভিউতে AI চালু নেই। আসল অ্যাপে এখানে AI প্রস্তাব আসবে।',
        });
      case 'quran-content':
        return _json(503, {
          'error': 'প্রিভিউতে কুরআনের টেক্সট দেখানো হয় না। আসল অ্যাপে যাচাই করা উৎস থেকে আসবে।',
        });
      default:
        return _json(200, {'ok': true, 'preview': true});
    }
  }

  // ------------------------------------------------------------------- rpc

  Object? _rpc(String fn, Map<String, dynamic> p, String? userId) {
    switch (fn) {
      case 'ensure_patient_tasks':
        return _ensureTasks(userId, p['p_local_date'] as String,
            p['p_timezone_offset_minutes'] as int? ?? 360);
      case 'ensure_patient_reminder_tasks':
        return <_Row>[];
      case 'record_task_completion':
        final task = _byId('task_instances', p['p_task_id']);
        if (task == null) throw _Problem(404, 'Task not found');
        final status = p['p_new_status'] as String;
        task
          ..['status'] = status
          ..['completed_at'] = status == 'completed' ? p['p_occurred_at'] : null
          ..['snoozed_until'] = status == 'snoozed' ? p['p_snoozed_until'] : null
          ..['skip_reason'] = status == 'skipped' ? p['p_skip_reason'] : null
          ..['updated_at'] = nowIso();
        return task;
      case 'admin_search_patients':
        final q = (p['p_query'] as String? ?? '').toLowerCase();
        final rows = table('patients').where((row) {
          if (q.isEmpty) return true;
          return '${row['full_name']} ${row['patient_code']} ${row['phone']}'
              .toLowerCase()
              .contains(q);
        }).toList()
          ..sort((a, b) =>
              (b['created_at'] as String).compareTo(a['created_at'] as String));
        return rows;
      case 'create_prescription':
        return _insert('prescriptions', {
          'patient_id': p['p_patient_id'],
          'raw_text': p['p_raw_text'],
          'session_date': p['p_session_date'],
          'visibility': p['p_visibility'] ?? 'patient',
          'created_by': userId,
        }, userId);
      case 'create_draft_care_plan':
        final versions = table('care_plans')
            .where((c) => c['patient_id'] == p['p_patient_id'])
            .map((c) => c['version'] as int);
        final plan = _insert('care_plans', {
          'patient_id': p['p_patient_id'],
          'prescription_id': p['p_prescription_id'],
          'version': (versions.isEmpty ? 0 : versions.reduce(max)) + 1,
          'name': p['p_name'],
          'start_date': p['p_start_date'],
          'end_date': p['p_end_date'],
          'created_by': userId,
        }, userId);
        final copyFrom = p['p_copy_from_plan_id'];
        if (copyFrom != null) {
          for (final action in table('plan_actions')
              .where((a) => a['care_plan_id'] == copyFrom)
              .toList()) {
            _insert('plan_actions', {
              ...action,
              'id': uuid(),
              'care_plan_id': plan['id'],
              'review_status': 'draft',
            }, userId);
          }
        }
        return plan;
      case 'publish_care_plan':
        final plan = _byId('care_plans', p['p_care_plan_id'])!;
        for (final other in table('care_plans')) {
          if (other['patient_id'] == plan['patient_id'] &&
              other['status'] == 'active') {
            other['status'] = 'inactive';
          }
        }
        plan
          ..['status'] = 'active'
          ..['published_at'] = nowIso()
          ..['published_by'] = userId;
        return plan;
      case 'archive_care_plan':
      case 'archive_empty_draft_for_prescription_import':
        final plan = _byId('care_plans', p['p_care_plan_id'])!;
        plan
          ..['status'] = 'archived'
          ..['archived_at'] = nowIso()
          ..['published_at'] = null
          ..['published_by'] = null;
        return plan;
      case 'save_plan_action':
      case 'save_ai_plan_action':
        return _savePlanAction(p, userId, ai: fn == 'save_ai_plan_action');
      case 'reject_plan_action':
        final action = _byId('plan_actions', p['p_action_id'])!;
        action['review_status'] = 'rejected';
        return action;
      case 'reorder_plan_actions':
        final ids = List<String>.from(p['p_action_ids'] as List);
        for (var i = 0; i < ids.length; i++) {
          _byId('plan_actions', ids[i])?['sort_order'] = i;
        }
        return _embedActions(table('plan_actions')
            .where((a) => a['care_plan_id'] == p['p_care_plan_id'])
            .toList()
          ..sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int)));
      case 'replace_draft_action_resources':
        final actionId = p['p_action_id'];
        table('plan_action_resources').removeWhere((r) => r['plan_action_id'] == actionId);
        final ids = List<String>.from(p['p_resource_ids'] as List? ?? const []);
        for (var i = 0; i < ids.length; i++) {
          _insert('plan_action_resources', {
            'plan_action_id': actionId,
            'content_item_id': ids[i],
            'sort_order': i,
            'created_by': userId,
          }, userId);
        }
        return ids.length;
      case 'replace_draft_action_quran_surahs':
        final actionId = p['p_action_id'];
        table('plan_action_quran_surahs').removeWhere((r) => r['plan_action_id'] == actionId);
        final surahs = p['p_surahs'] as List? ?? const [];
        for (var i = 0; i < surahs.length; i++) {
          final s = Map<String, dynamic>.from(surahs[i] as Map);
          _insert('plan_action_quran_surahs', {
            'plan_action_id': actionId,
            'surah_number': s['surah_number'],
            'title': s['title'],
            'sort_order': i,
            'created_by': userId,
          }, userId);
        }
        return surahs.length;
      case 'mark_patient_notification_opened':
        return true;
      case 'admin_get_user_routine_progress':
        return {'days': p['p_days'] ?? 7, 'actions': <dynamic>[], 'progress': <dynamic>[]};
      case 'adopt_published_routine_template':
      case 'admin_create_user_routine':
        return uuid();
      default:
        return null;
    }
  }

  _Row _savePlanAction(Map<String, dynamic> p, String? userId, {required bool ai}) {
    final values = <String, dynamic>{
      'care_plan_id': p['p_care_plan_id'],
      'type': p['p_type'],
      'title': p['p_title'],
      'instruction': p['p_instruction'],
      'count_target': p['p_count_target'],
      'duration_minutes': p['p_duration_minutes'],
      'frequency_rule': p['p_frequency_rule'],
      'time_window': p['p_time_window'],
      'exact_time': p['p_exact_time'],
      'start_date': p['p_start_date'],
      'end_date': p['p_end_date'],
      'review_status': p['p_review_status'] ?? (ai ? 'approved' : 'draft'),
      'reminder_enabled': p['p_reminder_enabled'] ?? false,
    };
    _Row action;
    final existing = _byId('plan_actions', p['p_action_id']);
    if (existing != null) {
      existing
        ..addAll(values)
        ..['updated_at'] = nowIso();
      action = existing;
    } else {
      final siblings = table('plan_actions')
          .where((a) => a['care_plan_id'] == p['p_care_plan_id']);
      action = _insert('plan_actions', {
        ...values,
        'sort_order': siblings.length,
        'created_by': userId,
      }, userId);
    }
    final contentId = p['p_content_item_id'];
    if (contentId != null) {
      table('plan_action_resources').removeWhere((r) => r['plan_action_id'] == action['id']);
      _insert('plan_action_resources', {
        'plan_action_id': action['id'],
        'content_item_id': contentId,
        'usage_note': p['p_resource_usage_note'],
        'created_by': userId,
      }, userId);
    }
    return _embedActions([action]).first;
  }

  List<_Row> _embedActions(List<_Row> actions) => _select(
        'plan_actions',
        actions,
        '*,plan_action_resources(sort_order,usage_note,content_items(*)),plan_action_quran_surahs(*)',
      );

  List<_Row> _ensureTasks(String? userId, String localDate, int offset) {
    final patientId = _patientIdForUser(userId);
    if (patientId == null) return [];
    final plan = table('care_plans')
        .where((c) => c['patient_id'] == patientId && c['status'] == 'active')
        .firstOrNull;
    if (plan == null) return [];
    final date = DateTime.parse(localDate);
    final created = <_Row>[];
    for (final action in table('plan_actions').where((a) =>
        a['care_plan_id'] == plan['id'] && a['review_status'] == 'approved')) {
      final exists = table('task_instances').any((t) =>
          t['plan_action_id'] == action['id'] && t['occurrence_date'] == localDate);
      if (exists) continue;
      created.add(_insert('task_instances', {
        'plan_action_id': action['id'],
        'patient_id': patientId,
        'scheduled_at': _scheduledAt(date, action),
        'occurrence_date': localDate,
        'timezone_offset_minutes': offset,
      }, userId));
    }
    return created;
  }

  // ------------------------------------------------------------- postgrest

  http.StreamedResponse _rest(
    http.BaseRequest request,
    String tableName,
    String body,
    String? userId,
  ) {
    final query = request.url.queryParametersAll;
    final select = query['select']?.first ?? '*';
    final filters = <MapEntry<String, String>>[];
    for (final entry in query.entries) {
      if (const {'select', 'order', 'limit', 'offset', 'on_conflict', 'columns'}
          .contains(entry.key)) {
        continue;
      }
      if (entry.key.endsWith('.order') ||
          entry.key.endsWith('.limit') ||
          entry.key.endsWith('.offset')) {
        continue;
      }
      for (final value in entry.value) {
        filters.add(MapEntry(entry.key, value));
      }
    }
    final prefer = request.headers['Prefer'] ?? request.headers['prefer'] ?? '';
    final accept = request.headers['Accept'] ?? request.headers['accept'] ?? '';
    final wantsObject = accept.contains('vnd.pgrst.object');
    final rows = visibleRows(tableName);
    List<_Row> result;
    var total = 0;

    switch (request.method) {
      case 'GET':
      case 'HEAD':
        var matched = rows.where((r) => _matchesTop(r, filters)).toList();
        final ordering = query['order']?.first;
        if (ordering != null) _sort(matched, ordering);
        total = matched.length;
        final offset = int.tryParse(query['offset']?.first ?? '') ?? 0;
        final limit = int.tryParse(query['limit']?.first ?? '');
        final range = request.headers['Range'] ?? request.headers['range'];
        var start = offset;
        int? end;
        if (range != null && range.contains('-')) {
          final parts = range.split('-');
          start = int.tryParse(parts[0]) ?? start;
          end = int.tryParse(parts[1]);
        }
        matched = matched.skip(start).toList();
        if (limit != null) matched = matched.take(limit).toList();
        if (end != null) matched = matched.take(end - start + 1).toList();
        result = _select(tableName, matched, select, filters: filters);
        result = result.where((r) => !r.containsKey('__drop')).toList();
      case 'POST':
        final decoded = jsonDecode(body.isEmpty ? '[]' : body);
        final inputs = decoded is List ? decoded : [decoded];
        final conflict = query['on_conflict']?.first;
        final upsert = prefer.contains('resolution=merge-duplicates') ||
            prefer.contains('resolution=ignore-duplicates');
        final written = <_Row>[];
        for (final input in inputs) {
          final map = Map<String, dynamic>.from(input as Map);
          if (upsert) {
            final keys = (conflict ?? 'id').split(',');
            final existing = rows
                .where((r) => keys.every((k) => r[k] == map[k]))
                .firstOrNull;
            if (existing != null) {
              if (prefer.contains('merge-duplicates')) existing.addAll(map);
              written.add(existing);
              continue;
            }
          }
          written.add(_insert(tableName, map, userId));
        }
        result = _select(tableName, written, select);
        total = result.length;
      case 'PATCH':
        final changes = Map<String, dynamic>.from(jsonDecode(body) as Map);
        final matched = rows.where((r) => _matchesTop(r, filters)).toList();
        for (final row in matched) {
          row.addAll(changes);
          if (row.containsKey('updated_at')) row['updated_at'] = nowIso();
        }
        result = _select(tableName, matched, select);
        total = result.length;
      case 'DELETE':
        final matched = rows.where((r) => _matchesTop(r, filters)).toList();
        table(tableName).removeWhere(matched.contains);
        result = _select(tableName, matched, select);
        total = result.length;
      default:
        throw _Problem(405, 'Method not allowed');
    }

    final headers = <String, String>{
      'content-range':
          result.isEmpty ? '*/$total' : '0-${result.length - 1}/$total',
    };
    if (request.method == 'HEAD') return _json(200, null, headers: headers);
    final returnsBody = request.method == 'GET' ||
        prefer.contains('return=representation');
    if (!returnsBody) return _json(201, null, headers: headers);
    if (wantsObject) {
      if (result.length != 1) {
        return _json(406, {
          'code': 'PGRST116',
          'message': 'JSON object requested, multiple (or no) rows returned',
          'details': 'The result contains ${result.length} rows',
          'hint': null,
        });
      }
      return _json(200, result.first, headers: headers);
    }
    return _json(200, result, headers: headers);
  }

  bool _matchesTop(_Row row, List<MapEntry<String, String>> filters) {
    for (final f in filters) {
      if (f.key.contains('.') && f.key != 'or' && f.key != 'and') continue;
      if (!_matchFilter(row, f.key, f.value)) return false;
    }
    return true;
  }

  bool _matchFilter(_Row row, String key, String expression) {
    if (key == 'or' || key == 'and') {
      final inner = expression.substring(1, expression.length - 1);
      final parts = _splitTop(inner);
      final results = parts.map((part) {
        final firstDot = part.indexOf('.');
        if (firstDot < 0) return true;
        final column = part.substring(0, firstDot);
        if (column == 'or' || column == 'and') {
          return _matchFilter(row, column, part.substring(firstDot));
        }
        return _matchFilter(row, column, part.substring(firstDot + 1));
      });
      return key == 'or' ? results.any((r) => r) : results.every((r) => r);
    }
    var expr = expression;
    var negate = false;
    if (expr.startsWith('not.')) {
      negate = true;
      expr = expr.substring(4);
    }
    final dot = expr.indexOf('.');
    if (dot < 0) return true;
    final op = expr.substring(0, dot);
    final raw = expr.substring(dot + 1);
    final value = row[key];
    bool outcome;
    switch (op) {
      case 'eq':
        outcome = _same(value, raw);
      case 'neq':
        outcome = !_same(value, raw);
      case 'gt':
      case 'gte':
      case 'lt':
      case 'lte':
        if (value == null) {
          outcome = false;
        } else {
          final cmp = _compare(value, raw);
          outcome = switch (op) {
            'gt' => cmp > 0,
            'gte' => cmp >= 0,
            'lt' => cmp < 0,
            _ => cmp <= 0,
          };
        }
      case 'like':
      case 'ilike':
        final pattern = RegExp(
          '^${RegExp.escape(Uri.decodeComponent(raw)).replaceAll(r'\*', '.*').replaceAll('%', '.*')}\$',
          caseSensitive: op == 'like',
          dotAll: true,
        );
        outcome = value != null && pattern.hasMatch(value.toString());
      case 'in':
        final list = _splitTop(raw.substring(1, raw.length - 1))
            .map((v) => v.replaceAll('"', ''));
        outcome = list.any((v) => _same(value, v));
      case 'is':
        outcome = switch (raw) {
          'null' => value == null,
          'true' => value == true,
          'false' => value == false,
          _ => value != null,
        };
      case 'cs':
        outcome = value is List &&
            _splitTop(raw.substring(1, raw.length - 1))
                .every((v) => value.map((e) => e.toString()).contains(v.replaceAll('"', '')));
      default:
        outcome = true;
    }
    return negate ? !outcome : outcome;
  }

  bool _same(Object? value, String raw) {
    if (value == null) return raw == 'null';
    if (value is bool) return value.toString() == raw;
    if (value is num) return num.tryParse(raw) == value;
    return value.toString() == Uri.decodeComponent(raw);
  }

  int _compare(Object value, String raw) {
    if (value is num) return value.compareTo(num.tryParse(raw) ?? 0);
    return value.toString().compareTo(raw);
  }

  void _sort(List<_Row> rows, String ordering) {
    final terms = ordering.split(',').map((t) => t.split('.')).toList();
    rows.sort((a, b) {
      for (final term in terms) {
        final column = term.first;
        if (column.contains('(')) continue;
        final desc = term.contains('desc');
        final nullsFirst = term.contains('nullsfirst');
        final av = a[column];
        final bv = b[column];
        int cmp;
        if (av == null && bv == null) {
          cmp = 0;
        } else if (av == null) {
          cmp = nullsFirst ? -1 : 1;
          if (desc) cmp = -cmp;
        } else if (bv == null) {
          cmp = nullsFirst ? 1 : -1;
          if (desc) cmp = -cmp;
        } else if (av is num && bv is num) {
          cmp = av.compareTo(bv);
        } else {
          cmp = av.toString().compareTo(bv.toString());
        }
        if (cmp != 0) return desc ? -cmp : cmp;
      }
      return 0;
    });
  }

  List<String> _splitTop(String input) {
    final parts = <String>[];
    var depth = 0;
    var quoted = false;
    var current = StringBuffer();
    for (final char in input.split('')) {
      if (char == '"') quoted = !quoted;
      if (!quoted && char == '(') depth++;
      if (!quoted && char == ')') depth--;
      if (!quoted && depth == 0 && char == ',') {
        parts.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) parts.add(current.toString().trim());
    return parts.where((p) => p.isNotEmpty).toList();
  }

  /// Projects rows through a PostgREST select string, resolving embeds via
  /// the real foreign keys exported from the migrations.
  List<_Row> _select(
    String tableName,
    List<_Row> rows,
    String select, {
    List<MapEntry<String, String>> filters = const [],
    String prefix = '',
  }) {
    final items = _splitTop(select.replaceAll(RegExp(r'\s+'), ''));
    final out = <_Row>[];
    for (final row in rows) {
      final projected = <String, dynamic>{};
      var drop = false;
      for (final item in items) {
        if (item == '*') {
          projected.addAll(row);
          continue;
        }
        final paren = item.indexOf('(');
        if (paren < 0) {
          var name = item;
          String? alias;
          if (name.contains(':')) {
            final parts = name.split(':');
            alias = parts[0];
            name = parts.sublist(1).join(':');
          }
          name = name.split('::').first;
          if (name.contains('->')) {
            final parts = name.split(RegExp('->>?'));
            Object? value = row[parts.first];
            for (final key in parts.skip(1)) {
              value = value is Map ? value[key] : null;
            }
            projected[alias ?? parts.last] = value;
          } else if (name == 'count') {
            projected[alias ?? 'count'] = rows.length;
          } else {
            projected[alias ?? name] = row[name];
          }
          continue;
        }
        var head = item.substring(0, paren);
        final inner = item.substring(paren + 1, item.length - 1);
        String? alias;
        if (head.contains(':')) {
          final parts = head.split(':');
          alias = parts[0];
          head = parts[1];
        }
        final bang = head.split('!');
        final target = bang.first;
        final hints = bang.skip(1).toSet();
        final inner_ = hints.contains('inner');
        final hint = hints.where((h) => h != 'inner' && h != 'left').firstOrNull;
        final key = alias ?? target;
        final path = prefix.isEmpty ? key : '$prefix.$key';
        final embedFilters = filters
            .where((f) => f.key.startsWith('$path.') &&
                !f.key.substring(path.length + 1).contains('.'))
            .map((f) => MapEntry(f.key.substring(path.length + 1), f.value))
            .toList();
        final resolved = _resolveEmbed(tableName, row, target, hint);
        if (resolved == null) {
          projected[key] = null;
          if (inner_) drop = true;
          continue;
        }
        final (embedTable, related, single) = resolved;
        final filtered = related
            .where((r) => _visible(embedTable, r))
            .where((r) => embedFilters.every((f) => _matchFilter(r, f.key, f.value)))
            .toList();
        final nested = _select(embedTable, filtered, inner,
                filters: filters, prefix: path)
            .where((r) => !r.containsKey('__drop'))
            .toList();
        if (single) {
          projected[key] = nested.firstOrNull;
          if (inner_ && nested.isEmpty) drop = true;
        } else {
          final order = filters
              .where((f) => f.key == '$path.order')
              .firstOrNull;
          if (order != null) _sort(nested, order.value);
          projected[key] = nested;
          if (inner_ && nested.isEmpty) drop = true;
        }
      }
      if (drop) projected['__drop'] = true;
      out.add(projected);
    }
    return out;
  }

  (String, List<_Row>, bool)? _resolveEmbed(
    String tableName,
    _Row row,
    String target,
    String? hint,
  ) {
    // Embedding through a foreign-key column name, e.g. category_id(...).
    for (final fk in _fks) {
      if (fk.table == tableName && fk.columns.first == target) {
        final match = table(fk.refTable)
            .where((r) => r[fk.refColumns.first] == row[fk.columns.first]);
        return (fk.refTable, match.toList(), true);
      }
    }
    // Many-to-one: this table references the target.
    for (final fk in _fks) {
      if (fk.table == tableName && fk.refTable == target) {
        if (hint != null && !fk.columns.contains(hint) && hint != target) {
          continue;
        }
        final match = table(target).where((r) {
          for (var i = 0; i < fk.columns.length; i++) {
            if (r[fk.refColumns[i]] != row[fk.columns[i]]) return false;
          }
          return true;
        });
        return (target, match.toList(), true);
      }
    }
    // One-to-many: the target references this table.
    for (final fk in _fks) {
      if (fk.table == target && fk.refTable == tableName) {
        if (hint != null && !fk.columns.contains(hint)) continue;
        final match = table(target).where((r) {
          for (var i = 0; i < fk.columns.length; i++) {
            if (r[fk.columns[i]] != row[fk.refColumns[i]]) return false;
          }
          return true;
        });
        return (target, match.toList(), false);
      }
    }
    return null;
  }
}

/// http.Client that routes every Supabase call to [PreviewBackend].
class PreviewHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await PreviewBackend.instance.handle(request);
    // Supabase clients read response.request, so attach the original.
    return http.StreamedResponse(
      response.stream,
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
