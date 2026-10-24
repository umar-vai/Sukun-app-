import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/presentation/public_resource_copy.dart';

void main() {
  test('keep real instructions but hide editor notes and book paragraph IDs', () {
    const input =
        'Owner-provided source; editorial review required before publishing.\n'
        '৫. সকাল-সন্ধ্যায় তিনবার পড়ুন।\n'
        'সেলফ রুকইয়াহ গাইড · paragraph 1177';
    expect(publicResourceInstructions(input), '৫. সকাল-সন্ধ্যায় তিনবার পড়ুন।');
  });

  test('ordinary article and guide body remains intact', () {
    const body = 'আল্লাহর নাম স্মরণ করুন।\nপ্রতিদিন নিয়মিত পড়ুন।';
    expect(publicResourceInstructions(body), body);
  });

  test('pure metadata-only body is hidden', () {
    expect(
      publicResourceInstructions(
        'Owner-provided source; editorial review required before publishing.',
      ),
      isNull,
    );
    expect(publicResourceInstructions(null), isNull);
  });
}
