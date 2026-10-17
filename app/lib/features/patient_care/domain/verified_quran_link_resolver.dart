import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

/// Quran links are canonical *references*, never AI-generated Quran text.
/// The actual Arabic/translation/audio is fetched from the existing approved
/// Quran Content API when a patient opens the reader.
class VerifiedQuranLink {
  const VerifiedQuranLink({
    required this.surahNumber,
    required this.title,
    this.ayahNumber,
  });

  final int surahNumber;
  final int? ayahNumber;
  final String title;

  String get route {
    final uri = Uri(
      path: '/resources/quran/$surahNumber',
      queryParameters: ayahNumber == null
          ? null
          : {'ayah': ayahNumber.toString()},
    );
    return uri.toString();
  }

  String get key => '$surahNumber:${ayahNumber ?? 0}';
}

/// Deterministic explicit-name mapping. Reject fuzzy names/verse guesses.
/// Do not add references when an instruction does not explicitly name them.
List<VerifiedQuranLink> verifiedQuranLinksForAction(PlanAction action) =>
    verifiedQuranLinksForText(
      title: action.title,
      instruction: action.instruction,
    );

/// Exposes the same deterministic Quran-reader references during Admin review.
/// No Quran text or third-party audio is inserted into the CMS, and a reader
/// reference is not a substitute for an approved matching audio resource.
List<VerifiedQuranLink> verifiedQuranLinksForText({
  required String title,
  String? instruction,
}) {
  final source = '$title ${instruction ?? ''}'.toLowerCase();
  final result = <VerifiedQuranLink>[];
  final seen = <String>{};
  void add(VerifiedQuranLink item) {
    if (seen.add(item.key)) result.add(item);
  }

  if (RegExp(
    r'আ[য়য়]াতুল\s*কুরস[িী]|ayat\s*(?:al[-\s]*)?kurs[iy]|آية\s*الكرسي',
    caseSensitive: false,
  ).hasMatch(source)) {
    add(
      const VerifiedQuranLink(
        surahNumber: 2,
        ayahNumber: 255,
        title: 'আয়াতুল কুরসি (২:২৫৫)',
      ),
    );
  }

  if (RegExp(
    r'(?:সূরা|সুরা|সূরাহ|surah|sura)\s*(?:আল[-\s]*)?ফালাক|'
    r'ফালাক[-–\s]*নাস|al[-\s]*falaq|surah\s*falaq',
    caseSensitive: false,
  ).hasMatch(source)) {
    add(const VerifiedQuranLink(surahNumber: 113, title: 'সূরা ফালাক'));
  }
  if (RegExp(
    r'(?:সূরা|সুরা|সূরাহ|surah|sura)\s*(?:আন[-\s]*)?নাস|'
    r'ফালাক[-–\s]*নাস|an[-\s]*nas|surah\s*nas',
    caseSensitive: false,
  ).hasMatch(source)) {
    add(const VerifiedQuranLink(surahNumber: 114, title: 'সূরা নাস'));
  }
  if (RegExp(
    r'(?:সূরা|সুরা|সূরাহ|surah|sura)\s*(?:আল[-\s]*)?ইখলাস|'
    r'surah\s*(?:al[-\s]*)?ikhlas',
    caseSensitive: false,
  ).hasMatch(source)) {
    add(const VerifiedQuranLink(surahNumber: 112, title: 'সূরা ইখলাস'));
  }
  if (RegExp(
    r'(?:সূরা|সুরা|সূরাহ|surah|sura)\s*(?:আল[-\s]*)?বাকার[াহ]|'
    r'surah\s*(?:al[-\s]*)?baqarah',
    caseSensitive: false,
  ).hasMatch(source)) {
    add(const VerifiedQuranLink(surahNumber: 2, title: 'সূরা বাকারা'));
  }
  return List.unmodifiable(result);
}
