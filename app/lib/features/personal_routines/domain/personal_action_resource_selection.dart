/// An ordered reference in a self-owned action. Canonical Quran content stays
/// in the verified reader; CMS content remains behind publication and RLS.
final class PersonalActionResourceSelection {
  const PersonalActionResourceSelection.cms(this.contentItemId)
    : provider = 'cms',
      surahNumber = null,
      ayahNumber = null;

  const PersonalActionResourceSelection.quran(this.surahNumber)
    : provider = 'quran',
      contentItemId = null,
      ayahNumber = null;

  const PersonalActionResourceSelection.quranAyah(
    this.surahNumber,
    this.ayahNumber,
  ) : provider = 'quran',
      contentItemId = null;

  final String provider;
  final String? contentItemId;
  final int? surahNumber;
  final int? ayahNumber;

  String get key => provider == 'cms'
      ? 'cms:$contentItemId'
      : ayahNumber == null
      ? 'quran:$surahNumber'
      : 'quran:$surahNumber:$ayahNumber';

  Map<String, String> get rpcValue => provider == 'cms'
      ? {'provider': 'cms', 'content_item_id': contentItemId!}
      : {'provider': 'quran', 'external_resource_ref': key};

  static List<PersonalActionResourceSelection> fromLinks(
    List<Map<String, dynamic>> links, {
    String? legacyContentId,
  }) {
    final selected = <PersonalActionResourceSelection>[];
    final seen = <String>{};
    for (final link in links) {
      PersonalActionResourceSelection? value;
      if (link['provider'] == 'cms' && link['content_item_id'] is String) {
        value = PersonalActionResourceSelection.cms(
          link['content_item_id'] as String,
        );
      } else if (link['provider'] == 'quran') {
        final reference = link['external_resource_ref'];
        final parts = reference is String ? reference.split(':') : <String>[];
        final surah = parts.length >= 2 && parts.first == 'quran'
            ? int.tryParse(parts[1])
            : null;
        final ayah = parts.length == 3 ? int.tryParse(parts[2]) : null;
        if ((parts.length == 2 || parts.length == 3) &&
            surah != null &&
            surah >= 1 &&
            surah <= 114 &&
            (parts.length == 2 || (ayah != null && ayah >= 1 && ayah <= 286))) {
          value = ayah == null
              ? PersonalActionResourceSelection.quran(surah)
              : PersonalActionResourceSelection.quranAyah(surah, ayah);
        }
      }
      if (value != null && seen.add(value.key)) selected.add(value);
    }
    if (selected.isEmpty && legacyContentId != null) {
      selected.add(PersonalActionResourceSelection.cms(legacyContentId));
    }
    return selected;
  }

  static void validate(List<PersonalActionResourceSelection> selected) {
    if (selected.length > 16 ||
        selected.map((item) => item.key).toSet().length != selected.length ||
        selected.any(
          (item) => item.provider == 'cms'
              ? item.contentItemId == null || item.contentItemId!.isEmpty
              : item.surahNumber == null ||
                    item.surahNumber! < 1 ||
                    item.surahNumber! > 114 ||
                    (item.ayahNumber != null &&
                        (item.ayahNumber! < 1 || item.ayahNumber! > 286)),
        )) {
      throw ArgumentError('Invalid resource selection');
    }
  }
}
