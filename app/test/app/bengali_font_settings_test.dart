import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/app/theme/bengali_font_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Bengali font choices include the licensed Sukun brand option', () {
    expect(BengaliFontChoice.values, hasLength(4));
    expect(
      BengaliFontChoice.values.map((choice) => choice.label),
      containsAll(['হিন্দ শিলিগুড়ি', 'অনেক বাংলা', 'তিরো বাংলা', 'Li Ador Noirrit']),
    );
  });

  test('Li Ador Noirrit cannot be chosen before real assets are bundled', () async {
    if (liAdorNoirritFontBundled) return;
    SharedPreferences.setMockInitialValues({});
    final settings = BengaliFontSettings.instance;
    final initial = settings.value;
    expect(BengaliFontChoice.liAdorNoirrit.isAvailable, isFalse);
    await settings.select(BengaliFontChoice.liAdorNoirrit);
    expect(settings.value, initial);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('sukun_display_bengali_font_v1'), isNull);
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

  test('saved but unavailable brand font safely falls back', () async {
    if (liAdorNoirritFontBundled) return;
    SharedPreferences.setMockInitialValues({
      'sukun_display_bengali_font_v1': 'liAdorNoirrit',
    });
    await BengaliFontSettings.instance.select(BengaliFontChoice.hindSiliguri);
    await BengaliFontSettings.instance.load();
    expect(BengaliFontSettings.instance.value, BengaliFontChoice.hindSiliguri);
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
