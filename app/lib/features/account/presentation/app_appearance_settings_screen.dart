import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/app_display_settings.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';

/// Non-clinical, on-device appearance and reading controls.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('অ্যাপ সেটিংস')),
      body: ValueListenableBuilder<AppDisplayPreferences>(
        valueListenable: AppDisplaySettings.instance,
        builder: (context, settings, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
          children: [
            Text('দেখার ধরন', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('অটো'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('লাইট'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('ডার্ক'),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (value) => unawaited(
                AppDisplaySettings.instance.setThemeMode(value.first),
              ),
            ),
            const SizedBox(height: 20),
            Text('রঙের থিম', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'সুকুনের মূল নীল রং ডিফল্ট। আপনার পছন্দের শান্ত রঙ নির্বাচন করুন।',
            ),
            const SizedBox(height: 10),
            Wrap(
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
            ),
            const SizedBox(height: 22),
            Text('পড়ার সুবিধা', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.font_download_outlined),
              title: const Text('বাংলা ফন্ট'),
              subtitle: const Text('একাধিক বাংলা ফন্ট থেকে নির্বাচন করুন'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/settings/bengali-font'),
            ),
            const Divider(),
            Text('বাংলা লেখার আকার · ${(_bengaliScale * 100).round()}%'),
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
            const SizedBox(height: 14),
            Text('আরবি লেখার আকার · ${(_arabicScale * 100).round()}%'),
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
            const SizedBox(height: 20),
            Text(
              'প্রার্থনা ও রিমাইন্ডার',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ListTile(
              leading: const Icon(Icons.access_time_rounded),
              title: const Text('নামাজের সময় ও হিসাবপদ্ধতি'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/prayer-times/settings'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('নোটিফিকেশন ও সমস্যা সমাধান'),
              subtitle: const Text('অনুমতি, রোগীর কাজ ও ব্যক্তিগত রিমাইন্ডার'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/settings/notifications'),
            ),
            const Text(
              'ব্রাউজার বন্ধ থাকলে নির্ভরযোগ্য রিমাইন্ডার দিতে অতিরিক্ত '
              'ওয়েব পুশ অনুমতি ও সেবা প্রয়োজন।',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
