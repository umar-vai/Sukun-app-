import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

const aiManualFallbackMessage =
    'Automatic action generation is temporarily unavailable. You can continue manually.';

enum AiActionGenerationStatus { generated, manualRequired }

class AiActionGenerationResult {
  const AiActionGenerationResult({
    required this.requestId,
    required this.status,
    required this.actions,
    this.sourceText,
  });

  factory AiActionGenerationResult.fromJson(
    Map<String, dynamic> json, {
    required String expectedRequestId,
  }) {
    final requestId = json['request_id'];
    if (requestId != expectedRequestId) {
      throw const AiActionSchemaException('Unexpected generation response.');
    }
    final status = switch (json['status']) {
      'generated' => AiActionGenerationStatus.generated,
      'manual_required' => AiActionGenerationStatus.manualRequired,
      _ => throw const AiActionSchemaException(
        'Unexpected generation response.',
      ),
    };
    final actionValues = json['actions'];
    if (actionValues is! List || actionValues.length > 50) {
      throw const AiActionSchemaException('Unexpected generation response.');
    }
    final actions = <SuggestedPlanAction>[];
    for (var index = 0; index < actionValues.length; index += 1) {
      final value = actionValues[index];
      if (value is! Map) {
        throw const AiActionSchemaException('Unexpected generation response.');
      }
      actions.add(
        SuggestedPlanAction.fromJson(
          Map<String, dynamic>.from(value),
          index: index,
        ),
      );
    }
    if (status == AiActionGenerationStatus.manualRequired &&
        actions.isNotEmpty) {
      throw const AiActionSchemaException('Unexpected generation response.');
    }
    return AiActionGenerationResult(
      requestId: requestId as String,
      status: status,
      actions: List.unmodifiable(actions),
      sourceText: _optionalText(json['source_text'], maxLength: 50000),
    );
  }

  final String requestId;
  final AiActionGenerationStatus status;
  final List<SuggestedPlanAction> actions;
  final String? sourceText;

  bool get requiresManualBuilder =>
      status == AiActionGenerationStatus.manualRequired || actions.isEmpty;
}

class SuggestedPlanAction {
  const SuggestedPlanAction({
    required this.index,
    required this.type,
    required this.title,
    required this.frequency,
    required this.confidence,
    required this.needsReview,
    required this.ambiguities,
    this.instruction,
    this.countTarget,
    this.durationMinutes,
    this.timeWindow,
    this.exactTime,
    this.resourceMatchQuery,
    this.sourceEvidence,
  });

  factory SuggestedPlanAction.fromJson(
    Map<String, dynamic> json, {
    required int index,
  }) {
    final type = _requiredText(json['type'], maxLength: 80);
    final title = _requiredText(json['title'], maxLength: 160);
    final instruction = _optionalText(json['instruction'], maxLength: 2000);
    final countTarget = _optionalPositiveInteger(json['count_target']);
    final durationMinutes = _optionalPositiveInteger(json['duration_minutes']);
    final frequency = _frequency(json['frequency']);
    final timeWindow = _timeWindow(json['time_window']);
    final exactTime = _exactTime(json['exact_time']);
    final resourceMatchQuery = _optionalText(
      json['resource_match_query'],
      maxLength: 160,
    );
    final sourceEvidence = _requiredText(
      json['source_evidence'],
      maxLength: 600,
    );
    final confidence = json['confidence'];
    if (confidence is! num || confidence < 0 || confidence > 1) {
      throw const AiActionSchemaException('Unexpected generation response.');
    }
    final needsReview = json['needs_review'];
    if (needsReview is! bool) {
      throw const AiActionSchemaException('Unexpected generation response.');
    }
    final ambiguityValues = json['ambiguities'];
    if (ambiguityValues is! List ||
        ambiguityValues.any((value) => value is! String)) {
      throw const AiActionSchemaException('Unexpected generation response.');
    }
    final ambiguities = ambiguityValues
        .cast<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(20)
        .toList(growable: false);

    return SuggestedPlanAction(
      index: index,
      type: type,
      title: title,
      instruction: instruction,
      countTarget: countTarget,
      durationMinutes: durationMinutes,
      frequency: frequency,
      timeWindow: timeWindow,
      exactTime: exactTime,
      resourceMatchQuery: resourceMatchQuery,
      sourceEvidence: sourceEvidence,
      confidence: confidence.toDouble(),
      needsReview: needsReview || ambiguities.isNotEmpty || frequency == null,
      ambiguities: List.unmodifiable(ambiguities),
    );
  }

  final int index;
  final String type;
  final String title;
  final String? instruction;
  final int? countTarget;
  final int? durationMinutes;
  final ActionFrequency? frequency;
  final String? timeWindow;
  final DateTime? exactTime;
  final String? resourceMatchQuery;
  final String? sourceEvidence;
  final double confidence;
  final bool needsReview;
  final List<String> ambiguities;
}

ActionReviewStatus importedReviewStatus(SuggestedPlanAction suggestion) =>
    suggestion.needsReview
    ? ActionReviewStatus.needsReview
    : ActionReviewStatus.draft;

class AiActionSchemaException implements Exception {
  const AiActionSchemaException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _requiredText(dynamic value, {required int maxLength}) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.trim().length > maxLength) {
    throw const AiActionSchemaException('Unexpected generation response.');
  }
  return value.trim();
}

String? _optionalText(dynamic value, {required int maxLength}) {
  if (value == null) return null;
  if (value is! String || value.trim().length > maxLength) {
    throw const AiActionSchemaException('Unexpected generation response.');
  }
  return value.trim().isEmpty ? null : value.trim();
}

int? _optionalPositiveInteger(dynamic value) {
  if (value == null) return null;
  if (value is! int || value < 1) {
    throw const AiActionSchemaException('Unexpected generation response.');
  }
  return value;
}

ActionFrequency? _frequency(dynamic value) {
  if (value == null) return null;
  if (value is! Map) {
    throw const AiActionSchemaException('Unexpected generation response.');
  }
  final json = Map<String, dynamic>.from(value);
  if (json['type'] == 'daily') {
    final interval = json['interval'];
    if (interval is! int || interval < 1) {
      throw const AiActionSchemaException('Unexpected generation response.');
    }
    return ActionFrequency.daily(interval: interval);
  }
  if (json['type'] == 'weekly') {
    final weekdayValues = json['weekdays'];
    if (weekdayValues is! List || weekdayValues.isEmpty) {
      throw const AiActionSchemaException('Unexpected generation response.');
    }
    final weekdays = weekdayValues.whereType<int>().toSet();
    if (weekdays.length != weekdayValues.length ||
        weekdays.any((day) => day < 1 || day > 7)) {
      throw const AiActionSchemaException('Unexpected generation response.');
    }
    return ActionFrequency.weekly(weekdays);
  }
  throw const AiActionSchemaException('Unexpected generation response.');
}

String? _timeWindow(dynamic value) {
  if (value == null) return null;
  const allowed = {'morning', 'afternoon', 'evening', 'night', 'anytime'};
  if (value is! String || !allowed.contains(value)) {
    throw const AiActionSchemaException('Unexpected generation response.');
  }
  return value;
}

DateTime? _exactTime(dynamic value) {
  if (value == null) return null;
  if (value is! String ||
      !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
    throw const AiActionSchemaException('Unexpected generation response.');
  }
  final parts = value.split(':');
  return DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
}


class AiActionReviewSeed {
  const AiActionReviewSeed({
    required this.result,
    this.attachmentId,
  });

  final AiActionGenerationResult result;
  final String? attachmentId;
}
