import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

/// One amal or supplement in a printable prescription. Times are left out on
/// purpose: the prescription says WHAT was given and in which section.
final class PrescriptionEntry {
  const PrescriptionEntry({
    required this.title,
    required this.sectionId,
    this.instruction,
  });

  final String title;
  final String? instruction;
  final String sectionId;
}

final class PrescriptionSection {
  const PrescriptionSection({
    required this.id,
    required this.title,
    required this.entries,
  });

  final String id;
  final String title;
  final List<PrescriptionEntry> entries;
}

/// Section order on the printed prescription.
const prescriptionSectionOrder = <(String, String)>[
  ('amal', 'আমল'),
  ('supplement', 'সাপ্লিমেন্ট'),
  ('bath', 'গোসল'),
  ('audio', 'অডিও ও তিলাওয়াত'),
  ('special', 'বিশেষ আমল'),
  ('other', 'অন্যান্য করণীয়'),
];

final _slotSuffix = RegExp(r'\s*\((সকাল|দুপুর|সন্ধ্যা|রাত)\)\s*$');

/// Removes the "(সকাল)" style suffix that bulk import adds when one item
/// repeats several times a day, so the item prints once.
String basePrescriptionTitle(String title) =>
    title.replaceFirst(_slotSuffix, '').trim();

/// Finds the section for an action. Official templates are matched by title;
/// anything else falls back to its type.
String prescriptionSectionFor({required String title, String? type}) {
  final base = basePrescriptionTitle(title);
  for (final template in officialPrescriptionTemplates) {
    if (template.title == base) return template.category;
  }
  return switch (type) {
    'amal' || 'dua' || 'dhikr' || 'hadith' => 'amal',
    'supplement' => 'supplement',
    'bath' => 'bath',
    'audio' || 'quran' || 'video' => 'audio',
    _ => 'other',
  };
}

PrescriptionEntry entryFromPlanAction(PlanAction action) => PrescriptionEntry(
  title: basePrescriptionTitle(action.title),
  instruction: action.instruction,
  sectionId: prescriptionSectionFor(title: action.title, type: action.type),
);

/// Entries from the admin overview RPC (`personal_routine_actions` rows).
PrescriptionEntry entryFromRoutineAction(Map<String, dynamic> action) {
  final title = action['title']?.toString() ?? '';
  return PrescriptionEntry(
    title: basePrescriptionTitle(title),
    instruction: action['notes']?.toString(),
    sectionId: prescriptionSectionFor(
      title: title,
      type: action['resource_type']?.toString(),
    ),
  );
}

/// Groups entries into ordered sections and drops repeats (the same item at
/// several times of day prints once).
List<PrescriptionSection> groupPrescription(Iterable<PrescriptionEntry> all) {
  final bySection = <String, List<PrescriptionEntry>>{};
  final seen = <String>{};
  for (final entry in all) {
    if (entry.title.isEmpty) continue;
    final key = '${entry.sectionId}|${entry.title}';
    if (!seen.add(key)) continue;
    bySection.putIfAbsent(entry.sectionId, () => []).add(entry);
  }
  return [
    for (final (id, title) in prescriptionSectionOrder)
      if (bySection[id]?.isNotEmpty == true)
        PrescriptionSection(id: id, title: title, entries: bySection[id]!),
  ];
}

/// Plain paragraph for a section: items flow one after another like normal
/// writing, not one per line.
String sectionParagraph(PrescriptionSection section) =>
    [for (final entry in section.entries) entryText(entry)].join('  ');

String entryText(PrescriptionEntry entry) {
  final instruction = entry.instruction?.trim();
  if (instruction == null || instruction.isEmpty) return '${entry.title}।';
  return '${entry.title}: $instruction';
}
