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
                subtitle: font.isAvailable
                    ? Text(
                        'সুকুন লাইফ — প্রতিদিনের আমল ও দোয়া',
                        style: SukunTypography.previewBengaliFont(font),
                      )
                    : const Text(
                        'অরিজিনাল ফন্ট ফাইল অ্যাপে যুক্ত হলে চালু হবে',
                      ),
                trailing: selected == font
                    ? const Icon(Icons.check_circle_rounded)
                    : const Icon(Icons.circle_outlined),
                onTap: font.isAvailable
                    ? () => unawaited(BengaliFontSettings.instance.select(font))
                    : null,
              ),
            ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Li Ador Noirrit-এর অরিজিনাল Regular, Light, ExtraLight, '
                'SemiBold, Bold ও Italic স্টাইল অ্যাপে রয়েছে। '
                'কুরআনের আরবি আয়াতের ফন্ট এই সেটিং বদলায় না।',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
