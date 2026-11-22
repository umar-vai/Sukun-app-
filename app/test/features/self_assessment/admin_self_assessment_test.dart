import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/self_assessment/data/self_assessment_repository.dart';
import 'package:sukun_life/features/self_assessment/domain/self_assessment.dart';
import 'package:sukun_life/features/self_assessment/presentation/admin_self_assessment_screens.dart';

final _test = SelfAssessmentTest.fromJson({
  'id': 'test-1',
  'slug': 'jinn',
  'title_bn': 'জিন যাচাই',
  'scoring_mode': 'total',
  'self_assessment_questions': [
    {
      'id': 'q1',
      'sort_order': 1,
      'question_bn': 'প্রথম লক্ষণ',
      'options': [
        {'label': 'হ্যাঁ', 'score': 10},
        {'label': 'না', 'score': 0},
      ],
    },
  ],
  'self_assessment_result_bands': [
    {'id': 'b0', 'min_score': 0, 'message_bn': 'নেই', 'needs_ruqyah': false},
  ],
});

void main() {
  testWidgets('admin edits test text and adds a question', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selfAssessmentRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: AdminSelfAssessmentEditScreen(testId: 'test-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1. প্রথম লক্ষণ'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('admin-self-title')),
      'নতুন শিরোনাম',
    );
    await tester.tap(find.byKey(const Key('admin-self-save-info')));
    await tester.pumpAndSettle();
    expect(repository.updates.single['title_bn'], 'নতুন শিরোনাম');

    await tester.tap(find.byKey(const Key('admin-self-add-question')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin-self-question-text')),
      'নতুন লক্ষণ',
    );
    await tester.tap(find.byKey(const Key('admin-self-question-save')));
    await tester.pumpAndSettle();

    final saved = repository.questions.single;
    expect(saved.questionBn, 'নতুন লক্ষণ');
    expect(saved.sortOrder, 2);
    expect(saved.options.map((option) => option.label), [
      'হ্যাঁ',
      'মাঝে মধ্যে',
      'না',
    ]);
    expect(tester.takeException(), isNull);
  });
}

final class _RecordingRepository implements SelfAssessmentRepository {
  final updates = <Map<String, dynamic>>[];
  final questions =
      <
        ({int sortOrder, String questionBn, List<SelfAssessmentOption> options})
      >[];

  @override
  Future<List<SelfAssessmentTest>> listTests() async => [_test];

  @override
  Future<SelfAssessmentTest?> getTest(String slug) async => _test;

  @override
  Future<void> updateTest(String testId, Map<String, dynamic> fields) async =>
      updates.add(fields);

  @override
  Future<void> saveQuestion({
    required String testId,
    String? questionId,
    required int sortOrder,
    required String questionBn,
    required List<SelfAssessmentOption> options,
  }) async => questions.add((
    sortOrder: sortOrder,
    questionBn: questionBn,
    options: options,
  ));

  @override
  Future<void> deleteQuestion(String questionId) async {}

  @override
  Future<void> saveBand({
    required String testId,
    String? bandId,
    required int minScore,
    required String messageBn,
    required bool needsRuqyah,
  }) async {}

  @override
  Future<void> deleteBand(String bandId) async {}
}
