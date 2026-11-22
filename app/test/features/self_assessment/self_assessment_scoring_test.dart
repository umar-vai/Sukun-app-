import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/self_assessment/domain/self_assessment.dart';

SelfAssessmentTest _totalTest() => SelfAssessmentTest.fromJson({
  'id': 't1',
  'slug': 'evil-eye',
  'title_bn': 'বদনজর',
  'scoring_mode': 'total',
  'self_assessment_questions': [
    for (var i = 1; i <= 3; i++)
      {
        'id': 'q$i',
        'sort_order': i,
        'question_bn': 'প্রশ্ন $i',
        'options': [
          {'label': 'হ্যাঁ', 'score': 10},
          {'label': 'মাঝে মধ্যে', 'score': 6},
          {'label': 'না', 'score': 0},
        ],
      },
  ],
  'self_assessment_result_bands': [
    {'id': 'b0', 'min_score': 0, 'message_bn': 'নেই', 'needs_ruqyah': false},
    {'id': 'b1', 'min_score': 11, 'message_bn': 'কম', 'needs_ruqyah': false},
    {'id': 'b2', 'min_score': 21, 'message_bn': 'বেশি', 'needs_ruqyah': true},
  ],
});

SelfAssessmentTest _dimensionTest() => SelfAssessmentTest.fromJson({
  'id': 't2',
  'slug': 'general',
  'title_bn': 'সাধারণ',
  'scoring_mode': 'dimensions',
  'fallback_bn': 'একাধিক লক্ষণ',
  'dimensions': [
    {'key': 'evil_eye', 'label_bn': 'বদনজর'},
    {'key': 'magic', 'label_bn': 'যাদু'},
  ],
  'rules': [
    {
      'when': {
        'evil_eye': {'max': 0},
        'magic': {'max': 0},
      },
      'flags': <String>[],
    },
    {
      'when': {
        'magic': {'min': 20},
      },
      'flags': ['magic'],
    },
    {
      'when': {
        'evil_eye': {'min': 20},
      },
      'flags': ['evil_eye'],
    },
  ],
  'outcomes': [
    {'flags': <String>[], 'message_bn': 'সমস্যা নেই', 'needs_ruqyah': false},
    {
      'flags': ['magic'],
      'message_bn': 'যাদু',
      'needs_ruqyah': true,
    },
    {
      'flags': ['evil_eye'],
      'message_bn': 'বদনজর',
      'needs_ruqyah': true,
    },
  ],
  'self_assessment_questions': [
    {
      'id': 'g1',
      'sort_order': 1,
      'question_bn': 'প্রশ্ন',
      'options': [
        {
          'label': 'হ্যাঁ',
          'scores': {'evil_eye': 25, 'magic': 5},
        },
        {
          'label': 'না',
          'scores': {'evil_eye': 0, 'magic': 0},
        },
      ],
    },
    {
      'id': 'g2',
      'sort_order': 2,
      'question_bn': 'প্রশ্ন ২',
      'options': [
        {
          'label': 'হ্যাঁ',
          'scores': {'evil_eye': 0, 'magic': 30},
        },
        {
          'label': 'না',
          'scores': {'evil_eye': 0, 'magic': 0},
        },
      ],
    },
  ],
});

void main() {
  test('total score picks the highest band it reaches', () {
    final test = _totalTest();
    expect(test.bands.map((band) => band.minScore), [21, 11, 0]);

    final none = scoreSelfAssessment(test, {'q1': 2, 'q2': 2, 'q3': 2});
    expect(none.totalScore, 0);
    expect(none.messageBn, 'নেই');
    expect(none.matchedQuestions, isEmpty);

    final low = scoreSelfAssessment(test, {'q1': 0, 'q2': 2, 'q3': 2});
    expect(low.totalScore, 10);
    expect(low.messageBn, 'নেই');

    final mid = scoreSelfAssessment(test, {'q1': 0, 'q2': 1, 'q3': 2});
    expect(mid.totalScore, 16);
    expect(mid.messageBn, 'কম');
    expect(mid.needsRuqyah, isFalse);
    expect(mid.matchedQuestions.map((q) => q.id), ['q1', 'q2']);

    final high = scoreSelfAssessment(test, {'q1': 0, 'q2': 0, 'q3': 1});
    expect(high.totalScore, 26);
    expect(high.messageBn, 'বেশি');
    expect(high.needsRuqyah, isTrue);
  });

  test('dimension scores use the first matching rule and its outcome', () {
    final test = _dimensionTest();

    final clean = scoreSelfAssessment(test, {'g1': 1, 'g2': 1});
    expect(clean.flaggedDimensions, isEmpty);
    expect(clean.messageBn, 'সমস্যা নেই');
    expect(clean.needsRuqyah, isFalse);

    // Magic is checked before evil eye, so both high flags magic only.
    final both = scoreSelfAssessment(test, {'g1': 0, 'g2': 0});
    expect(both.dimensionScores, {'evil_eye': 25, 'magic': 35});
    expect(both.flaggedDimensions, {'magic'});
    expect(both.messageBn, 'যাদু');

    final eye = scoreSelfAssessment(test, {'g1': 0, 'g2': 1});
    expect(eye.flaggedDimensions, {'evil_eye'});
    expect(eye.messageBn, 'বদনজর');
    expect(eye.needsRuqyah, isTrue);
  });

  test('a flag combination without an outcome uses the fallback text', () {
    final test = _dimensionTest();
    final json = {
      'id': 't3',
      'slug': 'general',
      'title_bn': 'সাধারণ',
      'scoring_mode': 'dimensions',
      'fallback_bn': 'একাধিক লক্ষণ',
      'rules': [
        {
          'when': {
            'evil_eye': {'min': 1},
          },
          'flags': ['evil_eye', 'magic'],
        },
      ],
      'outcomes': test.rawOutcomes,
      'self_assessment_questions': [
        {
          'id': 'x',
          'sort_order': 1,
          'question_bn': 'প্রশ্ন',
          'options': [
            {
              'label': 'হ্যাঁ',
              'scores': {'evil_eye': 5},
            },
            {
              'label': 'না',
              'scores': {'evil_eye': 0},
            },
          ],
        },
      ],
    };
    final parsed = SelfAssessmentTest.fromJson(json);
    final flagged = scoreSelfAssessment(parsed, {'x': 0});
    expect(flagged.flaggedDimensions, {'evil_eye', 'magic'});
    expect(flagged.messageBn, 'একাধিক লক্ষণ');
    expect(flagged.needsRuqyah, isTrue);

    // No rule matches: nothing is flagged, as in the original test logic.
    final none = scoreSelfAssessment(parsed, {'x': 1});
    expect(none.flaggedDimensions, isEmpty);
    expect(none.messageBn, 'সমস্যা নেই');
  });

  test('options round-trip to the stored JSON shape', () {
    const total = SelfAssessmentOption(label: 'হ্যাঁ', score: 8);
    const byDimension = SelfAssessmentOption(
      label: 'হ্যাঁ',
      scores: {'jinn': 4},
    );
    expect(total.toJson(), {'label': 'হ্যাঁ', 'score': 8});
    expect(byDimension.toJson(), {
      'label': 'হ্যাঁ',
      'scores': {'jinn': 4},
    });
    expect(SelfAssessmentOption.fromJson(byDimension.toJson()).scores, {
      'jinn': 4,
    });
  });
}
