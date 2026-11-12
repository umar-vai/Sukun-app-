import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:uuid/uuid.dart';

final class BulkCarePlanImportResult {
  const BulkCarePlanImportResult({
    required this.plan,
    required this.actionsAdded,
    required this.published,
  });

  final CarePlan plan;
  final int actionsAdded;

  /// False when the draft still holds earlier unreviewed (for example AI)
  /// actions. The new actions are saved, and the admin finishes that review.
  final bool published;
}

/// One-click template import for a patient.
///
/// Uses the existing audited Super Admin RPCs only: it reuses the open draft
/// (or starts a new version copied from the active plan so nothing already
/// prescribed is lost), saves each selected row as an approved daily action
/// with its reminder on, links resources, then publishes. Pressing the import
/// button is the admin's approval; this is not an AI path.
class BulkCarePlanImporter {
  BulkCarePlanImporter(
    this._repository, {
    String Function()? newRequestId,
    this.setNotificationTitle,
  }) : _newRequestId = newRequestId ?? (() => const Uuid().v4());

  final CarePlansRepository _repository;
  final String Function() _newRequestId;

  /// Saves the reminder name on a draft action. Null skips names (older
  /// callers and tests); the phone then shows the generic text.
  final Future<void> Function(String actionId, String? title)?
  setNotificationTitle;

  Future<BulkCarePlanImportResult> import({
    required String patientId,
    required List<BulkImportItem> items,
    required Map<String, ContentResourceOption> resourceLookup,
    DateTime? now,
  }) async {
    final drafts = expandBulkItems(items);
    if (drafts.isEmpty) {
      throw const CarePlanWorkflowException('কিছুই বাছাই করা হয়নি।');
    }
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);

    final plans = await _repository.getPatientPlans(patientId);
    CarePlan? draft;
    CarePlan? active;
    for (final plan in plans) {
      if (plan.status == CarePlanStatus.draft) draft ??= plan;
      if (plan.status == CarePlanStatus.active) active ??= plan;
    }
    final activeEnd = active?.endDate;
    final copiedFromActive = draft == null && active != null;
    final plan =
        draft ??
        await _repository.createDraft(
          CreateCarePlanInput(
            patientId: patientId,
            name: active?.name ?? 'সুকুন সেবা পরিকল্পনা',
            startDate: active == null || active.startDate.isAfter(today)
                ? today
                : active.startDate,
            endDate: activeEnd != null && !activeEnd.isBefore(today)
                ? activeEnd
                : null,
            copyFromPlanId: active?.id,
            requestId: _newRequestId(),
          ),
        );

    final start = plan.startDate.isAfter(today) ? plan.startDate : today;
    final planEnd = plan.endDate;
    if (planEnd != null && planEnd.isBefore(start)) {
      throw const CarePlanWorkflowException(
        'খোলা খসড়া পরিকল্পনার মেয়াদ শেষ। পরিকল্পনার তারিখ ঠিক করে আবার চেষ্টা করুন।',
      );
    }

    if (copiedFromActive) {
      // The new version starts as a copy of the live plan, and the database
      // marks copied rows needs_review. They were already approved and live,
      // so keep them approved instead of making the admin review them again.
      for (final action in await _repository.getActions(plan.id)) {
        if (action.reviewStatus != ActionReviewStatus.needsReview) continue;
        await _repository.saveAction(
          SavePlanActionInput(
            carePlanId: plan.id,
            actionId: action.id,
            type: action.type,
            title: action.title,
            instruction: action.instruction,
            countTarget: action.countTarget,
            durationMinutes: action.durationMinutes,
            frequency: action.frequency,
            timeWindow: action.timeWindow,
            exactTime: action.exactTime,
            startDate: action.startDate,
            endDate: action.endDate,
            reviewStatus: ActionReviewStatus.approved,
            reminderEnabled: action.reminderEnabled,
            requestId: _newRequestId(),
          ),
        );
        // Saving clears CMS links; put the copied ones back. Quran chapter
        // links live in their own table and are untouched.
        final cms = [
          for (final resource in action.linkedResources)
            if (!resource.id.startsWith('quran:')) resource.id,
        ];
        if (cms.isNotEmpty) {
          await _repository.replaceActionResources(
            actionId: action.id,
            resourceIds: cms,
            requestId: _newRequestId(),
          );
        }
      }
    }

    var added = 0;
    for (final item in drafts) {
      DateTime? end;
      var frequency = const ActionFrequency.daily();
      if (item.dates.isNotEmpty) {
        // Ghusl calendar: only today or later, inside the plan.
        final dates = {
          for (final date in item.dates)
            if (!date.isBefore(start) &&
                (planEnd == null || !date.isAfter(planEnd)))
              date,
        };
        if (dates.isEmpty) {
          throw CarePlanWorkflowException(
            '${item.title}: বাছাই করা সব তারিখ পার হয়ে গেছে বা পরিকল্পনার বাইরে।',
          );
        }
        frequency = ActionFrequency.dates(dates, ghusl: item.ghusl);
        end = frequency.sortedDates.last;
      } else {
        final days = item.durationDays;
        if (days != null) {
          end = start.add(Duration(days: days - 1));
        }
        if (planEnd != null && (end == null || end.isAfter(planEnd))) {
          end = planEnd;
        }
      }
      final saved = await _repository.saveAction(
        SavePlanActionInput(
          carePlanId: plan.id,
          type: item.type,
          title: item.title,
          instruction: item.instruction,
          frequency: frequency,
          timeWindow: item.time.timeWindow,
          exactTime: item.time.onDate(start),
          startDate: start,
          endDate: end,
          reviewStatus: ActionReviewStatus.approved,
          reminderEnabled: item.reminderEnabled,
          requestId: _newRequestId(),
        ),
      );
      final name = item.notificationTitle;
      if (name != null && setNotificationTitle != null) {
        await setNotificationTitle!(saved.id, name);
      }
      final cms = item.cmsResourceIds;
      if (cms.isNotEmpty) {
        await _repository.replaceActionResources(
          actionId: saved.id,
          resourceIds: cms,
          requestId: _newRequestId(),
        );
      }
      final surahs = [
        for (final number in item.quranSurahNumbers)
          resourceLookup['quran:$number'] ??
              ContentResourceOption(
                id: 'quran:$number',
                title: 'Surah $number',
                type: 'quran',
                visibility: 'public',
                status: 'published',
              ),
      ];
      if (surahs.isNotEmpty) {
        await _repository.replaceActionQuranSurahs(
          actionId: saved.id,
          surahs: surahs,
          requestId: _newRequestId(),
        );
      }
      added++;
    }

    final actions = await _repository.getActions(plan.id);
    final unresolved = actions.any(
      (action) =>
          action.reviewStatus != ActionReviewStatus.approved &&
          action.reviewStatus != ActionReviewStatus.rejected,
    );
    if (unresolved) {
      return BulkCarePlanImportResult(
        plan: plan,
        actionsAdded: added,
        published: false,
      );
    }
    final published = await _repository.publishPlan(plan.id, _newRequestId());
    return BulkCarePlanImportResult(
      plan: published,
      actionsAdded: added,
      published: true,
    );
  }
}
