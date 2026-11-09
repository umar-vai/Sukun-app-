import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';

/// Bangla label for a patient's account status.
String patientStatusLabel(PatientStatus status) => switch (status) {
  PatientStatus.active => 'চালু',
  PatientStatus.inactive => 'নিষ্ক্রিয়',
  PatientStatus.archived => 'সংরক্ষিত',
};

SukunStatusTone patientStatusTone(PatientStatus status) => switch (status) {
  PatientStatus.active => SukunStatusTone.success,
  PatientStatus.inactive => SukunStatusTone.warning,
  PatientStatus.archived => SukunStatusTone.neutral,
};

/// The first visible letter of a name (a full Bangla grapheme, never a
/// broken vowel sign), used for calm initial avatars instead of photos.
String nameInitial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
}

class PatientInitialAvatar extends StatelessWidget {
  const PatientInitialAvatar({super.key, required this.name, this.size = 46});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: SukunColors.mist,
      borderRadius: BorderRadius.circular(size * 0.32),
    ),
    child: ExcludeSemantics(
      child: Text(
        nameInitial(name),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: SukunColors.deepTide,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    ),
  );
}
