import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The bundled Li Ador Noirrit option is gated until the complete, approved
/// binary font family is present in the app's Flutter asset bundle.
/// This prevents a selectable option that silently renders an unrelated font.
const bool liAdorNoirritFontBundled = bool.fromEnvironment(
  'SUKUN_LI_ADOR_NOIRRIT_BUNDLED',
  defaultValue: false,
);
enum BengaliFontChoice {
  hindSiliguri('হিন্দ শিলিগুড়ি'),
  anekBangla('অনেক বাংলা'),
  tiroBangla('তিরো বাংলা'),
  liAdorNoirrit('Li Ador Noirrit');

  const BengaliFontChoice(this.label);
  final String label;

  bool get isAvailable => this != BengaliFontChoice.liAdorNoirrit ||
      liAdorNoirritFontBundled;
}


/// Display-only preferences: no patient records, Supabase or sensitive data.
class BengaliFontSettings extends ValueNotifier<BengaliFontChoice> {
  BengaliFontSettings._()
      : super(liAdorNoirritFontBundled
            ? BengaliFontChoice.liAdorNoirrit
            : BengaliFontChoice.hindSiliguri);

  static final BengaliFontSettings instance = BengaliFontSettings._();
  static const String _key = 'sukun_display_bengali_font_v1';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      final selection = BengaliFontChoice.values.where(
        (choice) => choice.name == stored,
      );
      if (selection.isNotEmpty && selection.first.isAvailable) {
        value = selection.first;
      }
    } catch (_) {
      // No font preference may prevent startup or clinical flows.
    }
  }

  Future<void> select(BengaliFontChoice font) async {
    if (!font.isAvailable) return;
    value = font;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, font.name);
    } catch (_) {
      // Current session keeps the chosen appearance when storage is blocked.
    }
  }
}
