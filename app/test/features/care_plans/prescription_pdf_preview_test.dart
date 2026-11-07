import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/presentation/prescription_pdf_preview.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('SukunLiAdorNoirrit')
      ..addFont(
        rootBundle.load(
          'assets/fonts/li_ador_noirrit/Li Ador Noirrit Regular.ttf',
        ),
      );
    await loader.load();
  });
  final date = DateTime(2026, 11, 7);
  final patient = Patient(
    id: 'synthetic-patient',
    userId: 'synthetic-user',
    patientCode: 'TEST-01',
    fullName: 'পরীক্ষার রোগী',
    status: PatientStatus.active,
    createdAt: date,
  );
  final plan = CarePlan(
    id: 'synthetic-plan',
    patientId: patient.id,
    version: 2,
    name: 'পরীক্ষার প্রেসক্রিপশন',
    startDate: date,
    status: CarePlanStatus.inactive,
    createdAt: date,
    publishedAt: date,
  );
  const instruction = 'প্রত্যেক বৃহস্পতিবার নির্ধারিত নির্দেশনা অনুসরণ করুন।';
  PlanAction action(String id, ActionReviewStatus status) => PlanAction(
    id: id,
    carePlanId: plan.id,
    type: 'amal',
    officialTemplateId: 'x01',
    title: 'বিশেষ করণীয় $id',
    instruction: instruction,
    exactTime: DateTime(2000, 1, 1, 8, 15),
    frequency: const ActionFrequency.weekly({4}),
    startDate: date,
    sortOrder: 0,
    reviewStatus: status,
    reminderEnabled: true,
  );
  final actions = [
    action('included', ActionReviewStatus.approved),
    action('excluded', ActionReviewStatus.needsReview),
  ];

  test('historical approved export uses exact instruction and schedule', () {
    final lines = prescriptionPdfLines(
      plan: plan,
      patient: patient,
      actions: actions,
    ).map((line) => line.text);
    expect(lines, contains(instruction));
    expect(lines, contains('বিশেষ আমল'));
    expect(lines, contains('বিশেষ করণীয় included'));
    expect(lines, isNot(contains('বিশেষ করণীয় excluded')));
    expect(
      lines.any((line) => line.contains('বৃহস্পতি') && line.contains('08:15')),
      isTrue,
    );
  });

  test('generates private A4 PDF bytes from shaped Flutter text', () async {
    final bytes = await renderPrescriptionPdf(
      plan: plan,
      patient: patient,
      actions: actions,
    );
    final pdf = latin1.decode(bytes);
    expect(pdf, startsWith('%PDF-'));
    expect(pdf, contains('/MediaBox'));
    expect(pdf.contains('/Subtype/Image'), isTrue);
  });
}
