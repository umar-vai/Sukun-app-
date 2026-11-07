import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

String prescriptionCategory(PlanAction action) {
  final template = officialPrescriptionTemplates
      .where((item) => item.id == action.officialTemplateId)
      .firstOrNull;
  final category = template?.category ?? action.type;
  return officialTemplateCategories
          .where((item) => item.id == category)
          .firstOrNull
          ?.title ??
      'অন্যান্য করণীয়';
}

String prescriptionDate(DateTime value) => [
  value.year.toString().padLeft(4, '0'),
  value.month.toString().padLeft(2, '0'),
  value.day.toString().padLeft(2, '0'),
].join('-');

String prescriptionTime(DateTime value) => [
  value.hour.toString().padLeft(2, '0'),
  value.minute.toString().padLeft(2, '0'),
].join(':');

String prescriptionFrequency(ActionFrequency frequency) {
  if (frequency.type == ActionFrequencyType.daily) {
    return frequency.interval == 1
        ? 'প্রতিদিন'
        : 'প্রতি ${frequency.interval} দিন পর';
  }
  const days = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহস্পতি', 'শুক্র', 'শনি', 'রবি'];
  final selected = frequency.weekdays.toList()..sort();
  return selected.map((day) => days[day - 1]).join(', ');
}

String? prescriptionWindow(String? value) => switch (value) {
  'morning' => 'সকাল',
  'afternoon' => 'দুপুর',
  'evening' => 'সন্ধ্যা',
  'night' => 'রাত',
  'anytime' => 'যেকোনো সময়',
  _ => null,
};
