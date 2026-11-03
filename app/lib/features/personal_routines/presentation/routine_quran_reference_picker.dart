import 'package:flutter/material.dart';
import 'package:sukun_life/features/personal_routines/presentation/personal_surah_picker.dart';
import 'package:sukun_life/features/resources/presentation/canonical_quran_ayah_picker.dart';

/// A single entrypoint from the Routine Resource Library to canonical Quran
/// content. The provider API, not local CMS records, supplies all 114 chapters
/// and their actual verses. Never copy Arabic/translation into the routine.
Future<String?> pickRoutineQuranReference(
  BuildContext context,
  bool wholeSurah, {
  required Set<String> selectedReferences,
}) async {
  if (wholeSurah) {
    final excluded = selectedReferences
        .where((ref) => RegExp(r'^quran:[0-9]+$').hasMatch(ref))
        .map((ref) => int.tryParse(ref.substring(6)))
        .whereType<int>()
        .toSet();
    final surah = await showPersonalSurahPicker(
      context: context,
      exclude: excluded,
    );
    return surah == null ? null : 'quran:$surah';
  }
  final choice = await showCanonicalQuranAyahPicker(
    context: context,
    excludedReferences: selectedReferences,
  );
  return choice?.reference;
}
