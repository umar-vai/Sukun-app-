import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

/// Repairs old, already-saved extraction results at presentation time.
/// The original AI result remains immutable. Every action still needs an
/// explicit Super Admin review before publication.
AiActionGenerationResult reconcileStoredAiResult(
  AiActionGenerationResult original,
) {
  if (original.requiresManualBuilder) return original;

  final unique = <String>{};
  final actions = <SuggestedPlanAction>[];
  final fullSource = _proof(original.sourceText ?? '');

  for (final item in original.actions) {
    final evidence = item.sourceEvidence ?? '';
    final proof = _proof(evidence);
    final confirmed = proof.isNotEmpty &&
        fullSource.isNotEmpty &&
        fullSource.contains(proof);
    final recurring = _hasDailyRecurrence(evidence);
    final both = _hasMorning(evidence) && _hasEvening(evidence);

    final frequency = item.frequency ??
        (recurring || both ? const ActionFrequency.daily() : null);

    // Split a *single prescribed daily instruction* into two independent
    // sessions; do not infer HH:mm or copy one clock to the other.
    final windows = both
        ? const <String>['morning', 'evening']
        : <String?>[item.timeWindow];

    for (final window in windows) {
      final needsSeparateTimeReview = both && item.exactTime != null;
      final cleanedTitle = item.title.replaceFirst(
        RegExp(r'\s*\((?:সকাল|সন্ধ্যা|morning|evening)\)\s*$', caseSensitive: false),
        '',
      );
      final title = both
          ? '${cleanedTitle.length > 146 ? cleanedTitle.substring(0, 146) : cleanedTitle} (${window == 'morning' ? 'সকাল' : 'সন্ধ্যা'})'
          : item.title;
      final ambiguities = <String>[
        for (final reason in item.ambiguities)
          if (!_isResolvedLegacyMetadataWarning(reason, frequency)) reason,
        if (needsSeparateTimeReview)
          'Confirm the separate reminder clock for this session.',
        if (!confirmed)
          'Verify this instruction against the original prescription before import.',
      ];
      // Do not override explicit uncertainty supplied by the AI other than
      // legacy missing-field warnings that are no longer meaningful.
      final hasUnresolvedReview = ambiguities.isNotEmpty ||
          frequency == null ||
          (!confirmed) ||
          (item.needsReview &&
              item.ambiguities.isEmpty &&
              item.frequency != null);
      final normalized = SuggestedPlanAction(
        index: item.index,
        type: item.type,
        title: title,
        instruction: item.instruction,
        countTarget: item.countTarget,
        durationMinutes: item.durationMinutes,
        frequency: frequency,
        timeWindow: window,
        exactTime: both ? null : item.exactTime,
        resourceMatchQuery: item.resourceMatchQuery,
        sourceEvidence: item.sourceEvidence,
        confidence: item.confidence,
        needsReview: hasUnresolvedReview,
        ambiguities: List.unmodifiable(ambiguities.toSet()),
      );

      // Source-backed identical work is not two different treatment tasks.
      // Distinct count, resource, daypart, instruction and durations are kept.
      final fingerprint = [
        _key(normalized.type),
        _key(normalized.title),
        _key(normalized.sourceEvidence ?? ''),
        normalized.countTarget,
        normalized.durationMinutes,
        normalized.frequency?.toJson().toString(),
        normalized.timeWindow,
        normalized.exactTime?.toIso8601String(),
        _key(normalized.resourceMatchQuery ?? ''),
      ].join('|');
      if (unique.add(fingerprint)) {
        actions.add(normalized);
      }
    }
  }
  return AiActionGenerationResult(
    requestId: original.requestId,
    status: original.status,
    sourceText: original.sourceText,
    failureCode: original.failureCode,
    actions: List.unmodifiable(actions),
  );
}

String _proof(String value) => value
    .replaceAll(RegExp(r'[\u200b-\u200d\ufeff]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

String _key(String value) => _proof(value)
    .replaceAll(RegExp(r'[।.,;:!?\-–—]'), '')
    .replaceAll(RegExp(r'\s+'), ' ');

bool _hasMorning(String text) =>
    RegExp(r'সকাল|ভোর|morning', caseSensitive: false).hasMatch(text);
bool _hasEvening(String text) =>
    RegExp(r'সন্ধ্যা|সান্ধ্য|evening', caseSensitive: false).hasMatch(text);

bool _hasDailyRecurrence(String text) =>
    RegExp(
      r'প্রতিদিন|প্রতি\s*দিন|দৈনিক|প্রতি\s*নামাজের\s*পর|প্রত্যেক\s*নামাজের\s*পর|every\s*day|daily',
      caseSensitive: false,
    ).hasMatch(text);

bool _isResolvedLegacyMetadataWarning(
  String reason,
  ActionFrequency? frequency,
) {
  if (frequency == null) return false;
  if (!reason.startsWith('AI omitted metadata fields:') &&
      !reason.startsWith('AI omitted or left empty metadata fields:')) {
    return false;
  }
  // Missing optional AI fields are not themselves clinical ambiguity.
  // Keep warnings for required provenance/type/title.
  return !RegExp(r'\b(source_evidence|title|type)\b').hasMatch(
    reason.split('Verify against the original prescription.').first,
  );
}
