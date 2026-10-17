/// An ordered reference in a self-owned action. Canonical Quran content stays
/// in the verified reader; CMS content remains behind publication and RLS.
final class PersonalActionResourceSelection {
  const PersonalActionResourceSelection.cms(this.contentItemId)
    : provider = 'cms',
      surahNumber = null;

  const PersonalActionResourceSelection.quran(this.surahNumber)
    : provider = 'quran',
      contentItemId = null;

  final String provider;
  final String? contentItemId;
  final int? surahNumber;

  String get key =>
      provider == 'cms' ? 'cms:$contentItemId' : 'quran:$surahNumber';

  Map<String, String> get rpcValue => provider == 'cms'
      ? {'provider': 'cms', 'content_item_id': contentItemId!}
      : {'provider': 'quran', 'external_resource_ref': 'quran:$surahNumber'};

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
        final number = reference is String && reference.startsWith('quran:')
            ? int.tryParse(reference.substring(6))
            : null;
        if (number != null && number >= 1 && number <= 114) {
          value = PersonalActionResourceSelection.quran(number);
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
                    item.surahNumber! > 114,
        )) {
      throw ArgumentError('Invalid resource selection');
    }
  }
}
