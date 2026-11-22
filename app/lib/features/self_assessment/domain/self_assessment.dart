/// Self-assessment tests: a symptom checklist that points to a suitable
/// ruqyah, never a medical diagnosis. Every question, score and result text
/// comes from the CMS, where a Super Admin can edit it.
library;

class SelfAssessmentOption {
  const SelfAssessmentOption({
    required this.label,
    this.score = 0,
    this.scores = const {},
  });

  factory SelfAssessmentOption.fromJson(Map<String, dynamic> json) {
    final raw = json['scores'];
    return SelfAssessmentOption(
      label: (json['label'] as String? ?? '').trim(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      scores: raw is Map
          ? {
              for (final entry in raw.entries)
                entry.key.toString(): (entry.value as num?)?.toInt() ?? 0,
            }
          : const {},
    );
  }

  final String label;

  /// Points for a test scored as one total.
  final int score;

  /// Points per dimension for a test scored by dimension (general test).
  final Map<String, int> scores;

  Map<String, dynamic> toJson() => {
    'label': label,
    if (scores.isEmpty) 'score': score else 'scores': scores,
  };

  SelfAssessmentOption copyWith({
    String? label,
    int? score,
    Map<String, int>? scores,
  }) => SelfAssessmentOption(
    label: label ?? this.label,
    score: score ?? this.score,
    scores: scores ?? this.scores,
  );
}

class SelfAssessmentQuestion {
  const SelfAssessmentQuestion({
    required this.id,
    required this.sortOrder,
    required this.questionBn,
    required this.options,
  });

  factory SelfAssessmentQuestion.fromJson(Map<String, dynamic> json) =>
      SelfAssessmentQuestion(
        id: json['id'] as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        questionBn: (json['question_bn'] as String? ?? '').trim(),
        options: [
          for (final option in (json['options'] as List? ?? const []))
            if (option is Map)
              SelfAssessmentOption.fromJson(Map<String, dynamic>.from(option)),
        ],
      );

  final String id;
  final int sortOrder;
  final String questionBn;
  final List<SelfAssessmentOption> options;
}

class SelfAssessmentBand {
  const SelfAssessmentBand({
    required this.id,
    required this.minScore,
    required this.messageBn,
    required this.needsRuqyah,
  });

  factory SelfAssessmentBand.fromJson(Map<String, dynamic> json) =>
      SelfAssessmentBand(
        id: json['id'] as String,
        minScore: (json['min_score'] as num?)?.toInt() ?? 0,
        messageBn: (json['message_bn'] as String? ?? '').trim(),
        needsRuqyah: json['needs_ruqyah'] == true,
      );

  final String id;
  final int minScore;
  final String messageBn;
  final bool needsRuqyah;
}

class SelfAssessmentDimension {
  const SelfAssessmentDimension({required this.key, required this.labelBn});

  final String key;
  final String labelBn;
}

/// One ordered rule of a dimension-scored test: the first rule whose every
/// bound holds decides which dimensions are flagged.
class SelfAssessmentRule {
  const SelfAssessmentRule({required this.when, required this.flags});

  factory SelfAssessmentRule.fromJson(Map<String, dynamic> json) {
    final when = <String, ({int? min, int? max})>{};
    final raw = json['when'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final bounds = entry.value;
        if (bounds is! Map) continue;
        when[entry.key.toString()] = (
          min: (bounds['min'] as num?)?.toInt(),
          max: (bounds['max'] as num?)?.toInt(),
        );
      }
    }
    return SelfAssessmentRule(
      when: when,
      flags: {
        for (final flag in (json['flags'] as List? ?? const []))
          flag.toString(),
      },
    );
  }

  final Map<String, ({int? min, int? max})> when;
  final Set<String> flags;

  bool matches(Map<String, int> totals) {
    for (final entry in when.entries) {
      final value = totals[entry.key] ?? 0;
      final min = entry.value.min;
      final max = entry.value.max;
      if (min != null && value < min) return false;
      if (max != null && value > max) return false;
    }
    return true;
  }
}

class SelfAssessmentOutcome {
  const SelfAssessmentOutcome({
    required this.flags,
    required this.messageBn,
    required this.needsRuqyah,
  });

  factory SelfAssessmentOutcome.fromJson(Map<String, dynamic> json) =>
      SelfAssessmentOutcome(
        flags: {
          for (final flag in (json['flags'] as List? ?? const []))
            flag.toString(),
        },
        messageBn: (json['message_bn'] as String? ?? '').trim(),
        needsRuqyah: json['needs_ruqyah'] == true,
      );

  final Set<String> flags;
  final String messageBn;
  final bool needsRuqyah;
}

class SelfAssessmentTest {
  const SelfAssessmentTest({
    required this.id,
    required this.slug,
    required this.titleBn,
    required this.scoringMode,
    this.descriptionBn,
    this.noteBn,
    this.fallbackBn,
    this.sortOrder = 0,
    this.isPublished = true,
    this.dimensions = const [],
    this.rules = const [],
    this.outcomes = const [],
    this.questions = const [],
    this.bands = const [],
    this.rawDimensions = const [],
    this.rawRules = const [],
    this.rawOutcomes = const [],
  });

  factory SelfAssessmentTest.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(Object? value) => [
      for (final item in (value as List? ?? const []))
        if (item is Map) Map<String, dynamic>.from(item),
    ];
    final dimensions = maps(json['dimensions']);
    final rules = maps(json['rules']);
    final outcomes = maps(json['outcomes']);
    final questions =
        maps(json['self_assessment_questions'])
            .map(SelfAssessmentQuestion.fromJson)
            .toList()
          ..sort((a, b) {
            final order = a.sortOrder.compareTo(b.sortOrder);
            return order != 0 ? order : a.id.compareTo(b.id);
          });
    final bands =
        maps(json['self_assessment_result_bands'])
            .map(SelfAssessmentBand.fromJson)
            .toList()
          ..sort((a, b) => b.minScore.compareTo(a.minScore));
    return SelfAssessmentTest(
      id: json['id'] as String,
      slug: json['slug'] as String,
      titleBn: (json['title_bn'] as String? ?? '').trim(),
      descriptionBn: json['description_bn'] as String?,
      noteBn: json['note_bn'] as String?,
      fallbackBn: json['fallback_bn'] as String?,
      scoringMode: json['scoring_mode'] as String? ?? 'total',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isPublished: json['is_published'] != false,
      dimensions: [
        for (final item in dimensions)
          SelfAssessmentDimension(
            key: item['key'].toString(),
            labelBn: (item['label_bn'] ?? item['key']).toString(),
          ),
      ],
      rules: rules.map(SelfAssessmentRule.fromJson).toList(growable: false),
      outcomes: outcomes
          .map(SelfAssessmentOutcome.fromJson)
          .toList(growable: false),
      questions: questions,
      bands: bands,
      rawDimensions: dimensions,
      rawRules: rules,
      rawOutcomes: outcomes,
    );
  }

  final String id;
  final String slug;
  final String titleBn;
  final String? descriptionBn;
  final String? noteBn;
  final String? fallbackBn;

  /// `total` sums one score; `dimensions` scores each dimension separately.
  final String scoringMode;
  final int sortOrder;
  final bool isPublished;
  final List<SelfAssessmentDimension> dimensions;
  final List<SelfAssessmentRule> rules;
  final List<SelfAssessmentOutcome> outcomes;
  final List<SelfAssessmentQuestion> questions;

  /// Highest minimum score first.
  final List<SelfAssessmentBand> bands;

  /// Original JSON, kept so the admin editor can show and edit it as text.
  final List<Map<String, dynamic>> rawDimensions;
  final List<Map<String, dynamic>> rawRules;
  final List<Map<String, dynamic>> rawOutcomes;

  bool get scoresByDimension => scoringMode == 'dimensions';
}

class SelfAssessmentResult {
  const SelfAssessmentResult({
    required this.messageBn,
    required this.needsRuqyah,
    required this.totalScore,
    this.dimensionScores = const {},
    this.flaggedDimensions = const {},
    this.matchedQuestions = const [],
  });

  final String messageBn;
  final bool needsRuqyah;
  final int totalScore;
  final Map<String, int> dimensionScores;
  final Set<String> flaggedDimensions;

  /// Questions answered with anything other than the last ("no") option.
  final List<SelfAssessmentQuestion> matchedQuestions;
}

/// Scores [answers] (question id → chosen option index) for [test].
/// Unanswered questions count as the last option, which scores zero.
SelfAssessmentResult scoreSelfAssessment(
  SelfAssessmentTest test,
  Map<String, int> answers,
) {
  var total = 0;
  final totals = <String, int>{};
  final matched = <SelfAssessmentQuestion>[];
  for (final question in test.questions) {
    if (question.options.isEmpty) continue;
    final index = answers[question.id];
    if (index == null || index < 0 || index >= question.options.length) {
      continue;
    }
    final option = question.options[index];
    total += option.score;
    for (final entry in option.scores.entries) {
      totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
    }
    if (index != question.options.length - 1) matched.add(question);
  }

  if (test.scoresByDimension) {
    final flags =
        test.rules
            .where((rule) => rule.matches(totals))
            .map((rule) => rule.flags)
            .firstOrNull ??
        const <String>{};
    final outcome = test.outcomes
        .where(
          (item) =>
              item.flags.length == flags.length &&
              item.flags.containsAll(flags),
        )
        .firstOrNull;
    return SelfAssessmentResult(
      messageBn:
          outcome?.messageBn ??
          test.fallbackBn?.trim() ??
          'ফলাফল নির্ণয় করা যায়নি। আবার চেষ্টা করুন।',
      needsRuqyah: outcome?.needsRuqyah ?? flags.isNotEmpty,
      totalScore: totals.values.fold(0, (sum, value) => sum + value),
      dimensionScores: totals,
      flaggedDimensions: flags,
      matchedQuestions: matched,
    );
  }

  final band = test.bands.where((item) => total >= item.minScore).firstOrNull;
  return SelfAssessmentResult(
    messageBn: band?.messageBn ?? 'ফলাফল নির্ণয় করা যায়নি। আবার চেষ্টা করুন।',
    needsRuqyah: band?.needsRuqyah ?? false,
    totalScore: total,
    matchedQuestions: matched,
  );
}
