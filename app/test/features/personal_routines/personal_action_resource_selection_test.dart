import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_action_resource_selection.dart';

void main() {
  test('mixed CMS and Quran links keep their saved order and payload', () {
    final selected = PersonalActionResourceSelection.fromLinks([
      {'provider': 'quran', 'external_resource_ref': 'quran:2'},
      {'provider': 'cms', 'content_item_id': 'audio-id'},
      {'provider': 'quran', 'external_resource_ref': 'quran:1'},
      {'provider': 'cms', 'content_item_id': 'pdf-id'},
    ]);

    expect(selected.map((item) => item.key), [
      'quran:2',
      'cms:audio-id',
      'quran:1',
      'cms:pdf-id',
    ]);
    expect(selected.map((item) => item.rpcValue), [
      {'provider': 'quran', 'external_resource_ref': 'quran:2'},
      {'provider': 'cms', 'content_item_id': 'audio-id'},
      {'provider': 'quran', 'external_resource_ref': 'quran:1'},
      {'provider': 'cms', 'content_item_id': 'pdf-id'},
    ]);
    PersonalActionResourceSelection.validate(selected);
  });

  test('specific Quran ayat have stable references and remain distinct', () {
    final selections = PersonalActionResourceSelection.fromLinks([
      {'provider': 'quran', 'external_resource_ref': 'quran:2:255'},
      {'provider': 'quran', 'external_resource_ref': 'quran:2'},
      {'provider': 'quran', 'external_resource_ref': 'quran:2:255'},
      {'provider': 'quran', 'external_resource_ref': 'quran:114:6'},
    ]);
    expect(selections.map((item) => item.key), [
      'quran:2:255',
      'quran:2',
      'quran:114:6',
    ]);
    expect(selections.first.ayahNumber, 255);
    expect(selections.first.rpcValue, {
      'provider': 'quran',
      'external_resource_ref': 'quran:2:255',
    });
    PersonalActionResourceSelection.validate(selections);
    expect(
      PersonalActionResourceSelection.fromLinks([
        {'provider': 'quran', 'external_resource_ref': 'quran:2:287'},
        {'provider': 'quran', 'external_resource_ref': 'quran:2:0'},
        {'provider': 'quran', 'external_resource_ref': 'quran:115:1'},
      ]),
      isEmpty,
    );
  });

  test('legacy single CMS link survives without creating a duplicate', () {
    final legacy = PersonalActionResourceSelection.fromLinks(
      [],
      legacyContentId: 'legacy-id',
    );
    expect(legacy.single.key, 'cms:legacy-id');
    final linked = PersonalActionResourceSelection.fromLinks([
      {'provider': 'cms', 'content_item_id': 'new-id'},
    ], legacyContentId: 'legacy-id');
    expect(linked.map((item) => item.key), ['cms:new-id']);
  });

  test('invalid and repeated canonical links cannot be saved', () {
    final parsed = PersonalActionResourceSelection.fromLinks([
      {'provider': 'quran', 'external_resource_ref': 'quran:115'},
      {'provider': 'quran', 'external_resource_ref': 'quran:2'},
      {'provider': 'quran', 'external_resource_ref': 'quran:2'},
    ]);
    expect(parsed.map((item) => item.key), ['quran:2']);
    expect(
      () => PersonalActionResourceSelection.validate([
        const PersonalActionResourceSelection.quran(2),
        const PersonalActionResourceSelection.quran(2),
      ]),
      throwsArgumentError,
    );
    expect(
      () => PersonalActionResourceSelection.validate([
        const PersonalActionResourceSelection.quran(115),
      ]),
      throwsArgumentError,
    );
  });
}
