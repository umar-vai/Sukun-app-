import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:sukun_life/features/care_plans/domain/stored_ai_suggestion_reconciler.dart';

const twice =
    'সকাল-সন্ধ্যা মাথায় হাত দিয়ে আয়াতুল কুরসি ও সূরা ফালাক-নাস ৭ বার করে পড়বেন।';

SuggestedPlanAction oldAction(
  String source, {
  int index = 0,
  String title = 'আয়াতুল কুরসি ও ফালাক-নাস',
  int? count = 7,
  String? resourceQuery,
  List<String> warnings = const [
    'AI omitted or left empty metadata fields: frequency, exact_time, duration_minutes, resource_match_query. Verify against the original prescription.',
  ],
}) => SuggestedPlanAction(
  index: index,
  type: 'recitation',
  title: title,
  instruction: source,
  countTarget: count,
  frequency: null,
  confidence: 0.94,
  needsReview: true,
  ambiguities: warnings,
  sourceEvidence: source,
  resourceMatchQuery: resourceQuery,
);

AiActionGenerationResult result(
  String source,
  List<SuggestedPlanAction> actions, {
  String? sourceText,
}) => AiActionGenerationResult(
  requestId: 'staging-test-request',
  status: AiActionGenerationStatus.generated,
  actions: actions,
  sourceText: sourceText ?? source,
);

void main() {
  test('already-stored duplicate extraction becomes two daily sessions', () {
    final raw = result(twice, [
      oldAction(twice),
      oldAction(twice, index: 1),
      oldAction(twice, index: 2),
    ]);
    final fixed = reconcileStoredAiResult(raw);
    expect(raw.actions, hasLength(3));
    expect(fixed.actions, hasLength(2));
    expect(fixed.actions.map((a) => a.timeWindow), ['morning', 'evening']);
    expect(fixed.actions.map((a) => a.frequency?.toJson()), [
      {'type': 'daily', 'interval': 1},
      {'type': 'daily', 'interval': 1},
    ]);
    expect(fixed.actions.map((a) => a.countTarget), [7, 7]);
    expect(fixed.actions.every((a) => a.exactTime == null), isTrue);
    expect(fixed.actions.every((a) => !a.needsReview), isTrue);
  });

  test('actual prescription text can verify old output with no source_text', () {
    final raw = result(twice, [oldAction(twice)], sourceText: ' ');
    final fixed = reconcileStoredAiResult(raw, prescriptionText: twice);
    expect(fixed.actions, hasLength(2));
    expect(fixed.actions.every((a) => !a.needsReview), isTrue);
  });

  test('AI-provided quote absent from prescription cannot be auto-ready', () {
    final raw = result('শুধু আগামীকাল সকালে পড়বেন।', [oldAction(twice)]);
    final fixed = reconcileStoredAiResult(raw);
    expect(fixed.actions, hasLength(2));
    expect(fixed.actions.every((a) => a.needsReview), isTrue);
  });

  test('a one-time morning mention never becomes daily without recurrence', () {
    const text = 'আগামীকাল সকালে আয়াতুল কুরসি পড়বেন।';
    final fixed = reconcileStoredAiResult(result(text, [oldAction(text)]));
    expect(fixed.actions, hasLength(1));
    expect(fixed.actions.single.frequency, isNull);
    expect(fixed.actions.single.needsReview, isTrue);
  });

  test('per-prayer recitation gains daily recurrence, not invented clocks', () {
    const text = 'প্রতি নামাজের পর তাসবিহে ফাতেমী পড়বেন।';
    final fixed = reconcileStoredAiResult(result(text, [oldAction(text)]));
    expect(fixed.actions, hasLength(1));
    expect(fixed.actions.single.frequency?.toJson(), {
      'type': 'daily',
      'interval': 1,
    });
    expect(fixed.actions.single.exactTime, isNull);
  });

  test('different repetition counts remain separate approved candidates', () {
    final fixed = reconcileStoredAiResult(
      result(twice, [
        oldAction(twice, count: 7),
        oldAction(twice, count: 11),
      ]),
    );
    expect(fixed.actions.map((a) => a.countTarget), [7, 7, 11, 11]);
  });

  test('different resources are never deduplicated together', () {
    final fixed = reconcileStoredAiResult(
      result(twice, [
        oldAction(twice, resourceQuery: '2:255'),
        oldAction(twice, resourceQuery: '113:1'),
      ]),
    );
    expect(fixed.actions, hasLength(4));
  });
}
