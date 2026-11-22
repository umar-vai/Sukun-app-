import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/self_assessment/data/self_assessment_repository.dart';
import 'package:sukun_life/features/self_assessment/domain/self_assessment.dart';
import 'package:sukun_life/features/self_assessment/presentation/self_assessment_screens.dart';

final _test = SelfAssessmentTest.fromJson({
  'id': 'test-1',
  'slug': 'waswasa',
  'title_bn': 'ওয়াসওয়াসা যাচাই',
  'description_bn': 'বিবরণ',
  'note_bn': 'এটি রোগনির্ণয় নয়।',
  'scoring_mode': 'total',
  'self_assessment_questions': [
    for (var i = 1; i <= 2; i++)
      {
        'id': 'q$i',
        'sort_order': i,
        'question_bn': 'লক্ষণ $i',
        'options': [
          {'label': 'হ্যাঁ', 'score': 30},
          {'label': 'না', 'score': 0},
        ],
      },
  ],
  'self_assessment_result_bands': [
    {
      'id': 'b0',
      'min_score': 0,
      'message_bn': 'আক্রান্ত নন',
      'needs_ruqyah': false,
    },
    {
      'id': 'b1',
      'min_score': 30,
      'message_bn': 'সম্ভাবনা আছে',
      'needs_ruqyah': true,
    },
  ],
});

void main() {
  Widget app() {
    final router = GoRouter(
      initialLocation: '/resources/self-diagnosis/test/waswasa',
      routes: [
        GoRoute(
          path: '/resources/self-diagnosis/test/:slug',
          builder: (_, state) =>
              SelfAssessmentTestScreen(slug: state.pathParameters['slug']!),
        ),
        GoRoute(
          path: '/resources/ruqyah',
          builder: (_, _) => const Scaffold(body: Text('ruqyah page')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        selfAssessmentRepositoryProvider.overrideWithValue(
          _FakeRepository(_test),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('a test asks every question before showing its result', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('১. লক্ষণ 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('self-test-submit')));
    await tester.pump();
    expect(find.byKey(const Key('self-test-result')), findsNothing);
    expect(find.textContaining('বাকি প্রশ্ন'), findsOneWidget);

    await tester.tap(find.byKey(const Key('self-option-q1-0')));
    await tester.tap(find.byKey(const Key('self-option-q2-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('self-test-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('self-test-result')), findsOneWidget);
    expect(find.text('সম্ভাবনা আছে'), findsOneWidget);
    expect(find.text('এটি রোগনির্ণয় নয়।'), findsOneWidget);
    expect(find.textContaining('মিলে যাওয়া লক্ষণ: ১টি'), findsOneWidget);
    expect(find.text('• লক্ষণ 1'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('self-test-restart')),
      200,
    );
    await tester.tap(find.byKey(const Key('self-test-restart')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('self-test-result')), findsNothing);
    expect(find.text('০/২ উত্তর দেওয়া হয়েছে'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a low score shows no ruqyah shortcut', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('self-option-q1-1')));
    await tester.tap(find.byKey(const Key('self-option-q2-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('self-test-submit')));
    await tester.pumpAndSettle();

    expect(find.text('আক্রান্ত নন'), findsOneWidget);
    expect(find.byKey(const Key('self-test-open-ruqyah')), findsNothing);
  });
}

final class _FakeRepository implements SelfAssessmentRepository {
  const _FakeRepository(this.test);

  final SelfAssessmentTest test;

  @override
  Future<List<SelfAssessmentTest>> listTests() async => [test];

  @override
  Future<SelfAssessmentTest?> getTest(String slug) async =>
      slug == test.slug ? test : null;

  @override
  Future<void> updateTest(String testId, Map<String, dynamic> fields) async {}

  @override
  Future<void> saveQuestion({
    required String testId,
    String? questionId,
    required int sortOrder,
    required String questionBn,
    required List<SelfAssessmentOption> options,
  }) async {}

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
