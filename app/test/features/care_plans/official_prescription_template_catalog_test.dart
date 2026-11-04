import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';

void main() {
  test('official catalog has all five photo-derived admin categories', () {
    expect(officialTemplateCategories.map((category) => category.title), [
      'আমল',
      'সাপ্লিমেন্ট',
      'গোসল',
      'অডিও',
      'বিশেষ আমল',
    ]);
    expect(officialPrescriptionTemplates, hasLength(51));
    expect(
      officialPrescriptionTemplates.map((item) => item.id).toSet(),
      hasLength(51),
    );
    for (final item in officialPrescriptionTemplates) {
      expect(
        officialTemplateCategories.any((group) => group.id == item.category),
        isTrue,
      );
      expect(item.instruction.trim(), isNotEmpty);
      expect(item.title.trim(), isNotEmpty);
    }
  });

  test('days and counts are never guessed from patient paperwork', () {
    final bath = findOfficialTemplate('b01')!;
    expect(bath.requiredVariables, ['দিন']);
    expect(() => bath.render({}), throwsArgumentError);
    expect(() => bath.render({'দিন': 0}), throwsArgumentError);
    expect(
      bath.render({'দিন': 7}),
      contains('7'), // numeric values come only from admin input
    );
  });

  test('audio draft explicitly requires matching published resource', () {
    final audio = findOfficialTemplate('u07')!;
    expect(audio.requiresLinkedResource, isTrue);
    expect(audio.requiredVariables, ['মিনিট']);
    expect(audio.render({'মিনিট': 30}), contains('30 মিনিট'));
    expect(findOfficialTemplate('missing'), isNull);
  });
}
