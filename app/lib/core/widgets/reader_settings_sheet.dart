import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sukun_life/app/theme/app_display_settings.dart';
import 'package:sukun_life/app/theme/bengali_font_settings.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';

/// A reusable, local-only reading action for Quran, Hadith, Ruqyah, articles
/// and PDF readers. It does not change verified source text or save to Supabase.
class ReaderSettingsAction extends StatelessWidget {
  const ReaderSettingsAction({
    super.key,
    this.showTranslationSwitch = false,
    this.pdfDocument = false,
    this.sourceLines = const [],
  });

  final bool showTranslationSwitch;
  final bool pdfDocument;
  final List<String> sourceLines;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: IconButton(
      key: const Key('reader-settings-gear'),
      tooltip: 'পাঠের সেটিংস',
      icon: const Icon(Icons.settings_rounded),
      iconSize: 24,
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF0A70A8),
        side: const BorderSide(color: Color(0xFF8EDCFA), width: 1.5),
        shape: const CircleBorder(),
        fixedSize: const Size(48, 48),
        padding: EdgeInsets.zero,
      ),
      onPressed: () => showReaderSettingsSheet(
        context,
        showTranslationSwitch: showTranslationSwitch,
        pdfDocument: pdfDocument,
        sourceLines: sourceLines,
      ),
    ),
  );
}

/// PDF page fonts are embedded in the file; the shared preferences affect
/// text-based readers, not the immutable PDF bytes. Its native zoom remains.
Future<void> showReaderSettingsSheet(
  BuildContext context, {
  bool showTranslationSwitch = false,
  bool pdfDocument = false,
  List<String> sourceLines = const [],
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.85,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: ValueListenableBuilder<AppDisplayPreferences>(
          valueListenable: AppDisplaySettings.instance,
          builder: (context, settings, _) =>
              ValueListenableBuilder<BengaliFontChoice>(
                valueListenable: BengaliFontSettings.instance,
                builder: (context, bengaliFont, _) => ListView(
                  key: const Key('reader-settings-panel'),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    Text(
                      'পাঠের সেটিংস',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'আপনার পছন্দ এই ডিভাইসে সংরক্ষিত থাকবে।',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (showTranslationSwitch) ...[
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        key: const Key('reader-bangla-translation'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('বাংলা অনুবাদ দেখান'),
                        subtitle: const Text('আরবি পাঠ সবসময় দৃশ্যমান থাকবে'),
                        value: settings.showQuranBanglaTranslation,
                        onChanged: (enabled) => unawaited(
                          AppDisplaySettings.instance
                              .setShowQuranBanglaTranslation(enabled),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const _SectionTitle('দেখার ধরন'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final (mode, label) in [
                          (ThemeMode.system, 'ডিভাইস অনুযায়ী'),
                          (ThemeMode.light, 'লাইট'),
                          (ThemeMode.dark, 'ডার্ক'),
                        ])
                          ChoiceChip(
                            key: Key('reader-theme-${mode.name}'),
                            label: Text(label),
                            selected: settings.themeMode == mode,
                            onSelected: (_) => unawaited(
                              AppDisplaySettings.instance.setThemeMode(mode),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _SectionTitle('রঙের থিম'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final palette in SukunAccentPalette.values)
                          ChoiceChip(
                            key: Key('reader-palette-${palette.name}'),
                            label: Text(palette.label),
                            avatar: CircleAvatar(
                              radius: 9,
                              backgroundColor: palette.previewColor,
                            ),
                            selected: settings.accentPalette == palette,
                            onSelected: (_) => unawaited(
                              AppDisplaySettings.instance.setAccentPalette(
                                palette,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 28),
                    const _SectionTitle('বাংলা ফন্ট'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final font in BengaliFontChoice.values)
                          if (font.isAvailable)
                            ChoiceChip(
                              key: Key('reader-bengali-font-${font.name}'),
                              label: Text(font.label),
                              selected: bengaliFont == font,
                              onSelected: (_) => unawaited(
                                BengaliFontSettings.instance.select(font),
                              ),
                            ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ScaleSetting(
                      title: 'বাংলা লেখার আকার',
                      key: const Key('reader-bengali-size'),
                      value: settings.bengaliScale,
                      min: 0.85,
                      max: 1.4,
                      divisions: 11,
                      onPreview:
                          AppDisplaySettings.instance.previewBengaliScale,
                      onSave: AppDisplaySettings.instance.setBengaliScale,
                    ),
                    Text(
                      'সুকুন লাইফ — সহজে পড়ুন',
                      style: SukunTypography.previewBengaliFont(
                        bengaliFont,
                        textStyle: TextStyle(
                          fontSize: 16 * settings.bengaliScale,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const Divider(height: 28),
                    const _SectionTitle('আরবি ফন্ট'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final font in ArabicReaderFont.values)
                          ChoiceChip(
                            key: Key('reader-arabic-font-${font.name}'),
                            label: Text(font.label),
                            selected: settings.arabicFont == font,
                            onSelected: (_) => unawaited(
                              AppDisplaySettings.instance.setArabicFont(font),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ScaleSetting(
                      title: 'আরবি লেখার আকার',
                      key: const Key('reader-arabic-size'),
                      value: settings.arabicScale,
                      min: 0.85,
                      max: 1.6,
                      divisions: 15,
                      onPreview: AppDisplaySettings.instance.previewArabicScale,
                      onSave: AppDisplaySettings.instance.setArabicScale,
                    ),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                        textAlign: TextAlign.center,
                        style: readerArabicStyle(
                          settings,
                          fontSize: 25 * settings.arabicScale,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ScaleSetting(
                      title: 'লাইনের ফাঁক',
                      key: const Key('reader-line-spacing'),
                      value: settings.readerLineSpacing,
                      min: 0.9,
                      max: 1.4,
                      divisions: 10,
                      onPreview:
                          AppDisplaySettings.instance.previewReaderLineSpacing,
                      onSave: AppDisplaySettings.instance.setReaderLineSpacing,
                    ),
                    if (pdfDocument) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'PDF-এর ভেতরের ফন্ট ও অনুবাদ এখানে বদলানো যায় না। '
                        'বড় করে পড়তে PDF-এর জুম বাটন ব্যবহার করুন।',
                      ),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const Key('reader-reset-preferences'),
                      onPressed: () => unawaited(
                        AppDisplaySettings.instance.resetReaderPreferences(),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('পড়ার সেটিংস রিসেট করুন'),
                    ),
                  ],
                ),
              ),
        ),
      ),
    ),
  ),
);

/// Unified typography for authenticated/guest Arabic reading surfaces.
/// Arabic glyphs and diacritics are never rewritten or transliterated.
TextStyle readerArabicStyle(
  AppDisplayPreferences settings, {
  required double fontSize,
  required Color color,
  double defaultHeight = 2.15,
}) {
  final height = defaultHeight * settings.readerLineSpacing;
  return switch (settings.arabicFont) {
    ArabicReaderFont.amiriQuran => GoogleFonts.amiriQuran(
      fontSize: fontSize,
      height: height,
      color: color,
      letterSpacing: 0,
    ),
    ArabicReaderFont.notoNaskhArabic => GoogleFonts.notoNaskhArabic(
      fontSize: fontSize,
      height: height,
      color: color,
      letterSpacing: 0,
    ),
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _ScaleSetting extends StatelessWidget {
  const _ScaleSetting({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onPreview,
    required this.onSave,
    super.key,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onPreview;
  final Future<void> Function(double) onSave;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$title · ${(value * 100).round()}%',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Slider(
        value: value.clamp(min, max).toDouble(),
        min: min,
        max: max,
        divisions: divisions,
        label: '${(value * 100).round()}%',
        onChanged: onPreview,
        onChangeEnd: (value) => unawaited(onSave(value)),
      ),
    ],
  );
}
