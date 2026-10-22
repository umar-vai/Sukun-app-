import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The user's own voluntary challenge is separate from patient prescriptions.
const challengeKey = 'sukun_40_day';

class ChallengeStage {
  const ChallengeStage(
    this.firstDay,
    this.lastDay,
    this.title,
    this.description,
  );
  final int firstDay;
  final int lastDay;
  final String title;
  final String description;
}

const fortyDayStages = <ChallengeStage>[
  ChallengeStage(
    1,
    9,
    'প্রস্তুতি',
    'চ্যালেঞ্জের নিয়ম ও যাচাইকৃত রিসোর্স দেখুন',
  ),
  ChallengeStage(
    10,
    12,
    'নজরের আমল',
    'নির্ধারিত রিসোর্স অনুযায়ী নিজের পরিকল্পনা অনুসরণ করুন',
  ),
  ChallengeStage(
    13,
    19,
    'বরই পাতার আমল',
    'অনুমোদিত নির্দেশনা ও সতর্কতা আগে পড়ে নিন',
  ),
  ChallengeStage(
    20,
    26,
    'আশফিয়া ডিটক্স',
    'যাচাইকৃত নির্দেশনা ছাড়া নতুন কিছু শুরু করবেন না',
  ),
  ChallengeStage(
    27,
    40,
    'জাদুর ডিটক্স',
    'নিজের সক্ষমতা অনুযায়ী ধাপে ধাপে এগিয়ে যান',
  ),
];

DateTime _dayOnly(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

int dayDifference(DateTime later, DateTime earlier) =>
    _dayOnly(later).difference(_dayOnly(earlier)).inDays;

String challengeDate(DateTime localDate) =>
    DateFormat('yyyy-MM-dd').format(localDate);

class ChallengeProgress {
  const ChallengeProgress({
    required this.startedOn,
    required this.pausedDays,
    required this.pausedOn,
    required this.completedDays,
  });

  final DateTime startedOn;
  final int pausedDays;
  final DateTime? pausedOn;
  final Set<int> completedDays;

  bool get isPaused => pausedOn != null;

  int dayAt(DateTime today) {
    // Pausing freezes the challenge clock; a missed day never wipes check-ins.
    final reference = isPaused ? pausedOn! : today;
    return (1 + dayDifference(reference, startedOn) - pausedDays)
        .clamp(1, 40)
        .toInt();
  }

  bool get complete => completedDays.length == 40;

  ChallengeStage stageAt(DateTime today) {
    final day = dayAt(today);
    return fortyDayStages.firstWhere(
      (stage) => day >= stage.firstDay && day <= stage.lastDay,
    );
  }
}

class ChallengeRepository {
  const ChallengeRepository(this.client);
  final SupabaseClient client;

  String get _owner {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('চ্যালেঞ্জে অংশ নিতে লগইন করুন।');
    return id;
  }

  Future<ChallengeProgress?> load() async {
    final owner = _owner;
    final row = await client
        .from('challenge_enrollments')
        .select('started_on,paused_on,paused_days')
        .eq('user_id', owner)
        .eq('challenge_key', challengeKey)
        .maybeSingle();
    if (owner != _owner) return null;
    if (row == null) return null;
    final entries = await client
        .from('challenge_day_checkins')
        .select('day_number')
        .eq('user_id', owner)
        .eq('challenge_key', challengeKey);
    if (owner != _owner) return null;
    return ChallengeProgress(
      startedOn: DateTime.parse(row['started_on'] as String),
      pausedDays: row['paused_days'] as int,
      pausedOn: row['paused_on'] == null
          ? null
          : DateTime.parse(row['paused_on'] as String),
      completedDays: {for (final row in entries) row['day_number'] as int},
    );
  }

  Future<void> enroll(DateTime today) async {
    final owner = _owner;
    // Never reset an existing challenge; first enrollment wins.
    final existing = await client
        .from('challenge_enrollments')
        .select('user_id')
        .eq('user_id', owner)
        .eq('challenge_key', challengeKey)
        .maybeSingle();
    if (existing != null) return;
    if (owner != _owner) return;
    await client.from('challenge_enrollments').insert({
      'user_id': owner,
      'challenge_key': challengeKey,
      'started_on': challengeDate(today),
    });
  }

  Future<void> pause(ChallengeProgress current, DateTime today) async {
    if (current.isPaused) return;
    final owner = _owner;
    await client
        .from('challenge_enrollments')
        .update({
          'paused_on': challengeDate(today),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', owner)
        .eq('challenge_key', challengeKey);
  }

  Future<void> resume(ChallengeProgress current, DateTime today) async {
    final paused = current.pausedOn;
    if (paused == null) return;
    final owner = _owner;
    await client
        .from('challenge_enrollments')
        .update({
          'paused_on': null,
          'paused_days':
              current.pausedDays +
              dayDifference(today, paused).clamp(0, 3650 - current.pausedDays),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', owner)
        .eq('challenge_key', challengeKey);
  }

  Future<void> markToday(ChallengeProgress current, DateTime today) async {
    if (current.isPaused || current.complete) {
      throw StateError('এখন এই দিনের কাজ চিহ্নিত করা যাবে না।');
    }
    final day = current.dayAt(today);
    if (current.completedDays.contains(day)) return;
    await client
        .from('challenge_day_checkins')
        .upsert(
          {'user_id': _owner, 'challenge_key': challengeKey, 'day_number': day},
          onConflict: 'user_id,challenge_key,day_number',
          ignoreDuplicates: true,
        );
  }

  Future<void> undoToday(ChallengeProgress current, DateTime today) async {
    final day = current.dayAt(today);
    await client
        .from('challenge_day_checkins')
        .delete()
        .eq('user_id', _owner)
        .eq('challenge_key', challengeKey)
        .eq('day_number', day);
  }
}
