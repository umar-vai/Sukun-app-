import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/app/theme/bengali_font_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Bengali font options include three actual font families', () {
    expect(BengaliFontChoice.values, hasLength(3));
    expect(
      BengaliFontChoice.values.map((choice) => choice.label),
      containsAll(['হিন্দ শিলিগুড়ি', 'অনেক বাংলা', 'তিরো বাংলা']),
    );
  });

  test('selected Bengali font persists on this device', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = BengaliFontSettings.instance;
    await settings.select(BengaliFontChoice.anekBangla);
    expect(settings.value, BengaliFontChoice.anekBangla);
    final stored = await SharedPreferences.getInstance();
    expect(
      stored.getString('sukun_display_bengali_font_v1'),
      BengaliFontChoice.anekBangla.name,
    );

    await settings.select(BengaliFontChoice.hindSiliguri);
  });

  test('invalid stored font never prevents safe initialization', () async {
    SharedPreferences.setMockInitialValues({
      'sukun_display_bengali_font_v1': 'unknown_font',
    });
    await BengaliFontSettings.instance.load();
    expect(
      BengaliFontChoice.values,
      contains(BengaliFontSettings.instance.value),
    );
  });
}
