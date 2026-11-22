import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/self_assessment/domain/self_assessment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelfAssessmentException implements Exception {
  const SelfAssessmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class SelfAssessmentRepository {
  /// Tests visible to the caller (RLS: published, or every test for a
  /// Super Admin), with questions and result bands.
  Future<List<SelfAssessmentTest>> listTests();

  Future<SelfAssessmentTest?> getTest(String slug);

  Future<void> updateTest(String testId, Map<String, dynamic> fields);

  Future<void> saveQuestion({
    required String testId,
    String? questionId,
    required int sortOrder,
    required String questionBn,
    required List<SelfAssessmentOption> options,
  });

  Future<void> deleteQuestion(String questionId);

  Future<void> saveBand({
    required String testId,
    String? bandId,
    required int minScore,
    required String messageBn,
    required bool needsRuqyah,
  });

  Future<void> deleteBand(String bandId);
}

const _testSelection =
    'id,slug,title_bn,description_bn,note_bn,scoring_mode,dimensions,rules,'
    'outcomes,fallback_bn,sort_order,is_published,'
    'self_assessment_questions(id,sort_order,question_bn,options),'
    'self_assessment_result_bands(id,min_score,message_bn,needs_ruqyah)';

final class SupabaseSelfAssessmentRepository
    implements SelfAssessmentRepository {
  const SupabaseSelfAssessmentRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw SelfAssessmentException(error.message);
    }
  }

  @override
  Future<List<SelfAssessmentTest>> listTests() => _guard(() async {
    final rows = await _client
        .from('self_assessment_tests')
        .select(_testSelection)
        .order('sort_order')
        .order('slug');
    return rows
        .map((row) => SelfAssessmentTest.fromJson(row))
        .toList(growable: false);
  });

  @override
  Future<SelfAssessmentTest?> getTest(String slug) => _guard(() async {
    final row = await _client
        .from('self_assessment_tests')
        .select(_testSelection)
        .eq('slug', slug)
        .maybeSingle();
    return row == null ? null : SelfAssessmentTest.fromJson(row);
  });

  @override
  Future<void> updateTest(String testId, Map<String, dynamic> fields) =>
      _guard(() async {
        await _client
            .from('self_assessment_tests')
            .update({...fields, 'updated_by': _client.auth.currentUser?.id})
            .eq('id', testId);
      });

  @override
  Future<void> saveQuestion({
    required String testId,
    String? questionId,
    required int sortOrder,
    required String questionBn,
    required List<SelfAssessmentOption> options,
  }) => _guard(() async {
    final values = {
      'sort_order': sortOrder,
      'question_bn': questionBn,
      'options': [for (final option in options) option.toJson()],
    };
    if (questionId == null) {
      await _client.from('self_assessment_questions').insert({
        ...values,
        'test_id': testId,
      });
    } else {
      await _client
          .from('self_assessment_questions')
          .update(values)
          .eq('id', questionId);
    }
  });

  @override
  Future<void> deleteQuestion(String questionId) => _guard(() async {
    await _client
        .from('self_assessment_questions')
        .delete()
        .eq('id', questionId);
  });

  @override
  Future<void> saveBand({
    required String testId,
    String? bandId,
    required int minScore,
    required String messageBn,
    required bool needsRuqyah,
  }) => _guard(() async {
    final values = {
      'min_score': minScore,
      'message_bn': messageBn,
      'needs_ruqyah': needsRuqyah,
    };
    if (bandId == null) {
      await _client.from('self_assessment_result_bands').insert({
        ...values,
        'test_id': testId,
      });
    } else {
      await _client
          .from('self_assessment_result_bands')
          .update(values)
          .eq('id', bandId);
    }
  });

  @override
  Future<void> deleteBand(String bandId) => _guard(() async {
    await _client
        .from('self_assessment_result_bands')
        .delete()
        .eq('id', bandId);
  });
}

final class UnavailableSelfAssessmentRepository
    implements SelfAssessmentRepository {
  const UnavailableSelfAssessmentRepository();

  static const _error = SelfAssessmentException(
    'Connect Supabase to use self-assessment tests.',
  );

  @override
  Future<List<SelfAssessmentTest>> listTests() async => throw _error;

  @override
  Future<SelfAssessmentTest?> getTest(String slug) async => throw _error;

  @override
  Future<void> updateTest(String testId, Map<String, dynamic> fields) async =>
      throw _error;

  @override
  Future<void> saveQuestion({
    required String testId,
    String? questionId,
    required int sortOrder,
    required String questionBn,
    required List<SelfAssessmentOption> options,
  }) async => throw _error;

  @override
  Future<void> deleteQuestion(String questionId) async => throw _error;

  @override
  Future<void> saveBand({
    required String testId,
    String? bandId,
    required int minScore,
    required String messageBn,
    required bool needsRuqyah,
  }) async => throw _error;

  @override
  Future<void> deleteBand(String bandId) async => throw _error;
}

final selfAssessmentRepositoryProvider = Provider<SelfAssessmentRepository>((
  ref,
) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const UnavailableSelfAssessmentRepository();
  }
  return SupabaseSelfAssessmentRepository(Supabase.instance.client);
});
