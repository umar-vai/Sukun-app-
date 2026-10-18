import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Only fonts currently available from the existing google_fonts dependency.
/// The licensed Sukun Li Ador Noirrit binary is a separate gated asset step.
enum BengaliFontChoice {
  hindSiliguri('হিন্দ শিলিগুড়ি'),
  anekBangla('অনেক বাংলা'),
  tiroBangla('তিরো বাংলা');

  const BengaliFontChoice(this.label);
  final String label;
}

/// Display-only preferences: no patient records, Supabase or sensitive data.
class BengaliFontSettings extends ValueNotifier<BengaliFontChoice> {
  BengaliFontSettings._() : super(BengaliFontChoice.hindSiliguri);

  static final BengaliFontSettings instance = BengaliFontSettings._();
  static const String _key = 'sukun_display_bengali_font_v1';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      final selection = BengaliFontChoice.values.where(
        (choice) => choice.name == stored,
      );
      if (selection.isNotEmpty) value = selection.first;
    } catch (_) {
      // No font preference may prevent startup or clinical flows.
    }
  }

  Future<void> select(BengaliFontChoice font) async {
    value = font;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, font.name);
    } catch (_) {
      // Current session keeps the chosen appearance when storage is blocked.
    }
  }
}
