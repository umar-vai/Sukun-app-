import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

/// A source-preserving Qur'an/Arabic reader.
///
/// Arabic is displayed without any rewriting, transliteration is shown only
/// when provided by reviewed CMS content, and missing pronunciation is
/// explicitly identified instead of being generated or guessed.
class AyahReadingCard extends StatelessWidget {
  const AyahReadingCard({
    super.key,
    required this.arabicText,
    this.transliteration,
    this.title,
    this.reference,
    this.onOpenDetail,
  });

  final String arabicText;
  final String? transliteration;
  final String? title;
  final String? reference;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final pronunciation = transliteration?.trim();
    return SukunSurface(
      tone: SukunSurfaceTone.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null && title!.trim().isNotEmpty) ...[
            Text(
              title!,
              style: SukunTypography.banglaBody(
                textStyle: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Text(
                'আরবি',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: SukunColors.deepTide,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (reference != null && reference!.trim().isNotEmpty)
                Flexible(
                  child: Text(
                    reference!,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Directionality(
            textDirection: TextDirection.rtl,
            child: SelectableText(
              arabicText,
              textAlign: TextAlign.right,
              style: SukunTypography.canonicalReligiousText(
                textStyle: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ExpansionTile(
            key: const ValueKey('bangla-pronunciation-dropdown'),
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(
              'বাংলা উচ্চারণ দেখুন',
              style: SukunTypography.banglaBody(
                textStyle: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  pronunciation?.isNotEmpty == true
                      ? pronunciation!
                      : 'যাচাইকৃত বাংলা উচ্চারণ এখনো যুক্ত হয়নি।',
                  textDirection: TextDirection.ltr,
                  style: SukunTypography.banglaBody(
                    textStyle: Theme.of(context).textTheme.bodyLarge,
                  ).copyWith(height: 1.75),
                ),
              ),
            ],
          ),
          if (onOpenDetail != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenDetail,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('বিস্তারিত দেখুন'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
