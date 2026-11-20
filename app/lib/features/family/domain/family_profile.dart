/// One selectable patient profile returned by `my_family_profiles()`.
///
/// A single patient account returns exactly one of these. Only fields the
/// patient is allowed to see are carried: no clinical or staff-only data.
class FamilyProfile {
  const FamilyProfile({
    required this.patientId,
    required this.fullName,
    this.relationshipLabel,
    this.displayOrder = 0,
    this.isPrimary = false,
    this.familyId,
    this.familyLabel,
  });

  factory FamilyProfile.fromJson(Map<String, dynamic> json) {
    final label = (json['relationship_label'] as String?)?.trim();
    final family = (json['family_label'] as String?)?.trim();
    return FamilyProfile(
      patientId: json['patient_id'] as String,
      fullName: ((json['full_name'] as String?) ?? '').trim(),
      relationshipLabel: label == null || label.isEmpty ? null : label,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isPrimary: json['is_primary'] == true,
      familyId: json['family_id'] as String?,
      familyLabel: family == null || family.isEmpty ? null : family,
    );
  }

  final String patientId;
  final String fullName;
  final String? relationshipLabel;
  final int displayOrder;

  /// True for the owner profile (the one that holds the family login).
  final bool isPrimary;
  final String? familyId;
  final String? familyLabel;

  /// Up to two leading letters for the avatar. Works for Bangla and Latin
  /// names by walking grapheme-safe runes of the first and last words.
  String get initials {
    final words = fullName
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return '?';
    String first(String word) {
      // A Bangla letter plus its vowel sign is two code points; keep the
      // base letter and any combining marks so the avatar never shows a
      // dangling vowel sign.
      final runes = word.runes.toList(growable: false);
      final buffer = StringBuffer()..writeCharCode(runes.first);
      for (final rune in runes.skip(1)) {
        if (_isCombining(rune)) {
          buffer.writeCharCode(rune);
        } else {
          break;
        }
      }
      return buffer.toString();
    }

    final head = first(words.first);
    if (words.length == 1) return head.toUpperCase();
    return '$head${first(words.last)}'.toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      other is FamilyProfile &&
      other.patientId == patientId &&
      other.fullName == fullName &&
      other.relationshipLabel == relationshipLabel &&
      other.isPrimary == isPrimary;

  @override
  int get hashCode =>
      Object.hash(patientId, fullName, relationshipLabel, isPrimary);
}

bool _isCombining(int rune) =>
    (rune >= 0x0980 && rune <= 0x09FF && _banglaMarks.contains(rune)) ||
    (rune >= 0x0300 && rune <= 0x036F);

// Bangla signs, vowel signs, virama, and chandrabindu/anusvara/visarga.
const _banglaMarks = <int>{
  0x0981, 0x0982, 0x0983, 0x09BC, 0x09BE, 0x09BF, 0x09C0, 0x09C1, 0x09C2, //
  0x09C3, 0x09C4, 0x09C7, 0x09C8, 0x09CB, 0x09CC, 0x09CD, 0x09D7,
};
