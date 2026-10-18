import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/bengali_font_settings.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';

class BengaliFontSettingsScreen extends StatelessWidget {
  const BengaliFontSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('বাংলা ফন্ট সেটিংস')),
    body: ValueListenableBuilder<BengaliFontChoice>(
      valueListenable: BengaliFontSettings.instance,
      builder: (context, selected, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Text(
            'বাংলা লেখার ফন্ট',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'পছন্দের ফন্ট নির্বাচন করুন। এই ডিভাইসে সেটিংটি সংরক্ষিত থাকবে।',
          ),
          const SizedBox(height: 16),
          for (final font in BengaliFontChoice.values)
            Card(
              child: ListTile(
                key: Key('font-choice-${font.name}'),
                title: Text(font.label),
                subtitle: Text(
                  'সুকুন লাইফ — প্রতিদিনের আমল ও দোয়া',
                  style: SukunTypography.previewBengaliFont(font),
                ),
                trailing: selected == font
                    ? const Icon(Icons.check_circle_rounded)
                    : const Icon(Icons.circle_outlined),
                onTap: () => unawaited(
                  BengaliFontSettings.instance.select(font),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'সুকুন লাইফের নির্ধারিত Li Ador Noirrit ফন্ট '
                'মূল ব্র্যান্ড ডিফল্ট হিসেবে যুক্ত হবে অনুমোদিত ফন্ট '
                'ফাইল অ্যাপে সংযুক্ত ও যাচাই হওয়ার পর। '
                'কুরআনের আরবি আয়াতের ফন্ট এই সেটিং বদলায় না।',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
