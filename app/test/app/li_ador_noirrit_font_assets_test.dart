import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/theme/bengali_font_settings.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fonts = [
    'Li Ador Noirrit ExtraLight.ttf',
    'Li Ador Noirrit ExtraLight Italic.ttf',
    'Li Ador Noirrit Light.ttf',
    'Li Ador Noirrit Light Italic.ttf',
    'Li Ador Noirrit Regular.ttf',
    'Li Ador Noirrit Italic.ttf',
    'Li Ador Noirrit SemiBold.ttf',
    'Li Ador Noirrit SemiBold Italic.ttf',
    'Li Ador Noirrit Bold.ttf',
    'Li Ador Noirrit Bold Italic.ttf',
  ];

  test(
    'all ten licensed Li Ador Noirrit TTF faces load from Flutter assets',
    () async {
      for (final filename in fonts) {
        final data = await rootBundle.load(
          'assets/fonts/li_ador_noirrit/$filename',
        );
        expect(data.lengthInBytes, greaterThan(80000), reason: filename);
        // All supplied originals use the TrueType sfnt version 0x00010000.
        expect(data.getUint32(0), 0x00010000, reason: filename);
      }
    },
  );

  test('branded family can be selected with original font weight', () {
    expect(liAdorNoirritFontBundled, isTrue);
    expect(BengaliFontChoice.liAdorNoirrit.isAvailable, isTrue);
    final body = SukunTypography.previewBengaliFont(
      BengaliFontChoice.liAdorNoirrit,
    );
    final heading = SukunTypography.previewBengaliFont(
      BengaliFontChoice.liAdorNoirrit,
      fontWeight: FontWeight.w700,
    );
    expect(body.fontFamily, 'SukunLiAdorNoirrit');
    expect(heading.fontFamily, 'SukunLiAdorNoirrit');
    expect(heading.fontWeight, FontWeight.w700);
  });
}
