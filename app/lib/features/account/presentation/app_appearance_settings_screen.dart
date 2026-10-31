import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/app_display_settings.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

/// Local-only reader and appearance choices. No account/clinical data writes.
class AppAppearanceSettingsScreen extends StatefulWidget {
  const AppAppearanceSettingsScreen({super.key});

  @override
  State<AppAppearanceSettingsScreen> createState() =>
      _AppAppearanceSettingsScreenState();
}

class _AppAppearanceSettingsScreenState
    extends State<AppAppearanceSettingsScreen> {
  late double _bengaliScale;
  late double _arabicScale;

  @override
  void initState() {
    super.initState();
    final saved = AppDisplaySettings.instance.value;
    _bengaliScale = saved.bengaliScale;
    _arabicScale = saved.arabicScale;
  }

  Widget _themeChoices(AppDisplayPreferences settings) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final (mode, label, icon) in [
        (ThemeMode.system, 'অটো', Icons.brightness_auto_outlined),
        (ThemeMode.light, 'লাইট', Icons.light_mode_outlined),
        (ThemeMode.dark, 'ডার্ক', Icons.dark_mode_outlined),
      ])
        ChoiceChip(
          key: Key('appearance-theme-${mode.name}'),
          avatar: Icon(icon, size: 18),
          label: Text(label),
          selected: settings.themeMode == mode,
          onSelected: (_) => unawaited(
            AppDisplaySettings.instance.setThemeMode(mode),
          ),
        ),
    ],
  );

  Widget _paletteChoices(AppDisplayPreferences settings) => Wrap(
    spacing: 9,
    runSpacing: 9,
    children: [
      for (final palette in SukunAccentPalette.values)
        ChoiceChip(
          key: Key('accent-palette-${palette.name}'),
          label: Text(palette.label),
          avatar: CircleAvatar(
            radius: 10,
            backgroundColor: palette.previewColor,
          ),
          selected: settings.accentPalette == palette,
          onSelected: (_) => unawaited(
            AppDisplaySettings.instance.setAccentPalette(palette),
          ),
        ),
    ],
  );

  Widget _readerControls(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsPanel(
      title: 'পড়ার সুবিধা',
      description: 'পছন্দ অনুযায়ী লেখা বড় বা ছোট করুন।',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            key: const Key('appearance-font-choice'),
            contentPadding: EdgeInsets.zero,
            leading: const SukunIconBadge(
              icon: Icons.font_download_outlined,
              size: 42,
            ),
            title: const Text('বাংলা ফন্ট'),
            subtitle: const Text('উপলব্ধ বাংলা ফন্ট নির্বাচন করুন'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings/bengali-font'),
          ),
          const Divider(height: 24),
          Text(
            'বাংলা লেখার আকার · ${(_bengaliScale * 100).round()}%',
            style: theme.textTheme.titleSmall,
          ),
          Slider(
            key: const Key('bengali-font-size'),
            value: _bengaliScale,
            min: 0.85,
            max: 1.4,
            divisions: 11,
            label: '${(_bengaliScale * 100).round()}%',
            onChanged: (value) {
              setState(() => _bengaliScale = value);
              AppDisplaySettings.instance.previewBengaliScale(value);
            },
            onChangeEnd: (value) =>
                unawaited(AppDisplaySettings.instance.setBengaliScale(value)),
          ),
          Text(
            'সুকুন লাইফ — আজকের আমল',
            style: SukunTypography.banglaBody(
              textStyle: TextStyle(fontSize: 16 * _bengaliScale),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'আরবি লেখার আকার · ${(_arabicScale * 100).round()}%',
            style: theme.textTheme.titleSmall,
          ),
          Slider(
            key: const Key('arabic-font-size'),
            value: _arabicScale,
            min: 0.85,
            max: 1.6,
            divisions: 15,
            label: '${(_arabicScale * 100).round()}%',
            onChanged: (value) {
              setState(() => _arabicScale = value);
              AppDisplaySettings.instance.previewArabicScale(value);
            },
            onChangeEnd: (value) =>
                unawaited(AppDisplaySettings.instance.setArabicScale(value)),
          ),
          Text(
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            textAlign: TextAlign.center,
            style: SukunTypography.canonicalReligiousText(
              textStyle: TextStyle(fontSize: 26 * _arabicScale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderControls(BuildContext context) => _SettingsPanel(
    title: 'নামাজ ও রিমাইন্ডার',
    description: 'সময় ও নোটিফিকেশন আপনার নিয়ন্ত্রণে।',
    child: Column(
      children: [
        ListTile(
          key: const Key('appearance-prayer-settings'),
          contentPadding: EdgeInsets.zero,
          leading: const SukunIconBadge(
            icon: Icons.access_time_rounded,
            size: 42,
          ),
          title: const Text('নামাজের সময় ও হিসাবপদ্ধতি'),
          subtitle: const Text('অবস্থান ও সময় গণনার পদ্ধতি'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/prayer-times/settings'),
        ),
        const Divider(height: 1),
        ListTile(
          key: const Key('appearance-notification-settings'),
          contentPadding: EdgeInsets.zero,
          leading: const SukunIconBadge(
            icon: Icons.notifications_active_outlined,
            size: 42,
          ),
          title: const Text('নোটিফিকেশন ও সমস্যা সমাধান'),
          subtitle: const Text('অনুমতি, রোগীর কাজ ও নিজের রিমাইন্ডার'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/settings/notifications'),
        ),
        const SizedBox(height: 8),
        Text(
          'ব্রাউজার বন্ধ থাকলে রিমাইন্ডারের জন্য আলাদা Web Push সেবা ও অনুমতি প্রয়োজন।',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('অ্যাপ সেটিংস')),
    body: ValueListenableBuilder<AppDisplayPreferences>(
      valueListenable: AppDisplaySettings.instance,
      builder: (context, settings, _) => LayoutBuilder(
        builder: (context, bounds) {
          final wide = bounds.maxWidth >= 760;
          final horizontal = wide ? 28.0 : 16.0;
          final themeCard = _SettingsPanel(
            title: 'দেখার ধরন',
            description: 'আপনার চোখের আরাম অনুযায়ী মোড নির্বাচন করুন।',
            child: _themeChoices(settings),
          );
          final paletteCard = _SettingsPanel(
            title: 'রঙের থিম',
            description: 'সুকুন ব্লু ডিফল্ট। পছন্দের অন্য রংও বেছে নিতে পারেন।',
            child: _paletteChoices(settings),
          );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                key: const Key('appearance-page-scroll'),
                padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
                children: [
                  const SukunPageIntro(
                    eyebrow: 'পছন্দ ও সেটিংস',
                    title: 'অ্যাপ নিজের মতো সাজান',
                    subtitle: 'রং, থিম, ফন্ট ও রিমাইন্ডার সহজে নিয়ন্ত্রণ করুন।',
                  ),
                  const SizedBox(height: 20),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: themeCard),
                        const SizedBox(width: 18),
                        Expanded(child: paletteCard),
                      ],
                    )
                  else ...[
                    themeCard,
                    const SizedBox(height: 16),
                    paletteCard,
                  ],
                  const SizedBox(height: 16),
                  _readerControls(context),
                  const SizedBox(height: 16),
                  _reminderControls(context),
                  const SizedBox(height: 16),
                  Text(
                    'এই পছন্দগুলো আপনার বর্তমান ডিভাইসে সংরক্ষিত থাকে।',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => SukunSurface(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}
