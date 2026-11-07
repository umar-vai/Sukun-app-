import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_home_screen.dart';

void main() {
  final day = DateTime(2026, 11, 7);
  final plan = CarePlan(
    id: 'synthetic-plan',
    patientId: 'synthetic-patient',
    version: 1,
    name: 'Synthetic plan',
    startDate: day,
    status: CarePlanStatus.active,
    createdAt: day,
  );
  PatientTask task({
    List<LinkedResource> resources = const [],
    String patientId = 'synthetic-patient',
    String planId = 'synthetic-plan',
    ActionReviewStatus review = ActionReviewStatus.approved,
    PatientTaskStatus status = PatientTaskStatus.pending,
  }) => PatientTask(
    id: 'synthetic-task',
    patientId: patientId,
    occurrenceDate: day,
    status: status,
    action: PlanAction(
      id: 'synthetic-action',
      carePlanId: planId,
      type: 'amal',
      title: 'Synthetic instruction',
      frequency: const ActionFrequency.daily(),
      startDate: day,
      sortOrder: 0,
      reviewStatus: review,
      reminderEnabled: true,
      resources: resources,
    ),
  );

  test('opens the exact linked reader or playable audio of an owned task', () {
    const audio = LinkedResource(
      id: 'audio-1',
      title: 'Synthetic audio',
      type: 'audio',
      mediaUrl: 'https://example.invalid/synthetic.mp3',
    );
    const quran = LinkedResource(
      id: 'quran:114',
      title: 'Synthetic chapter reference',
      type: 'quran',
      publicRoute: '/resources/quran/114',
    );
    expect(
      resourceForPatientReminder(task(resources: [audio]), plan),
      same(audio),
    );
    expect(
      resourceForPatientReminder(task(resources: [quran]), plan),
      same(quran),
    );
  });

  test('passive, unavailable and multiple-resource tasks stay in Today', () {
    const unavailableAudio = LinkedResource(
      id: 'audio-1',
      title: 'Unavailable',
      type: 'audio',
    );
    const link = LinkedResource(
      id: 'external-1',
      title: 'External instruction',
      type: 'external_link',
    );
    expect(resourceForPatientReminder(task(), plan), isNull);
    expect(resourceForPatientReminder(task(resources: [link]), plan), isNull);
    expect(
      resourceForPatientReminder(task(resources: [unavailableAudio]), plan),
      isNull,
    );
    expect(
      resourceForPatientReminder(
        task(resources: [link, unavailableAudio]),
        plan,
      ),
      isNull,
    );
  });

  test('cross-patient, inactive-plan and unapproved task destinations are rejected', () {
    const quran = LinkedResource(
      id: 'quran:114',
      title: 'Synthetic chapter reference',
      type: 'quran',
      publicRoute: '/resources/quran/114',
    );
    expect(
      resourceForPatientReminder(
        task(resources: [quran], patientId: 'other'),
        plan,
      ),
      isNull,
    );
    expect(
      resourceForPatientReminder(task(resources: [quran], planId: 'old'), plan),
      isNull,
    );
    expect(
      resourceForPatientReminder(
        task(resources: [quran], review: ActionReviewStatus.needsReview),
        plan,
      ),
      isNull,
    );
    expect(
      resourceForPatientReminder(
        task(resources: [quran], status: PatientTaskStatus.completed),
        plan,
      ),
      isNull,
    );
  });
}
