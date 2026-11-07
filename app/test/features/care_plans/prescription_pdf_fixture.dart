import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';

final _date = DateTime(2026, 11, 7);
final pdfFixturePatient = Patient(
  id: 'synthetic-patient',
  userId: 'synthetic-user',
  patientCode: 'TEST-01',
  fullName: 'পরীক্ষার রোগী',
  status: PatientStatus.active,
  createdAt: _date,
);
final pdfFixturePlan = CarePlan(
  id: 'synthetic-plan',
  patientId: pdfFixturePatient.id,
  version: 2,
  name: 'পরীক্ষার প্রেসক্রিপশন',
  startDate: _date,
  status: CarePlanStatus.inactive,
  createdAt: _date,
  publishedAt: _date,
);
const pdfFixtureInstruction =
    'প্রত্যেক বৃহস্পতিবার নির্ধারিত নির্দেশনা অনুসরণ করুন।';
PlanAction _action(String id, ActionReviewStatus status) => PlanAction(
  id: id,
  carePlanId: pdfFixturePlan.id,
  type: 'amal',
  officialTemplateId: 'x01',
  title: 'বিশেষ করণীয় $id',
  instruction: pdfFixtureInstruction,
  exactTime: DateTime(2000, 1, 1, 8, 15),
  frequency: const ActionFrequency.weekly({4}),
  startDate: _date,
  sortOrder: 0,
  reviewStatus: status,
  reminderEnabled: true,
);
final pdfFixtureActions = [
  _action('included', ActionReviewStatus.approved),
  _action('excluded', ActionReviewStatus.needsReview),
];
