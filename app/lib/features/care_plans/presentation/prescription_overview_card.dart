import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/prescription_overview.dart';
import 'package:sukun_life/features/care_plans/data/prescription_pdf.dart';
import 'package:sukun_life/features/care_plans/domain/prescription_summary.dart';

/// Admin/raqi view of everything a person follows, in two parts:
/// what Sukun gave (with PDF download) and, only if there is any, what the
/// person added for themselves.
class PrescriptionOverviewCard extends StatefulWidget {
  const PrescriptionOverviewCard({
    super.key,
    required this.recipientName,
    required this.overview,
    required this.selfLabel,
    this.onDownload,
  });

  final String recipientName;
  final Future<PrescriptionOverview> overview;

  /// "রোগী নিজে যোগ করেছেন" or "ইউজার নিজে যোগ করেছেন".
  final String selfLabel;

  /// Test hook; defaults to building and sharing the real PDF.
  final Future<void> Function(List<PrescriptionSection> sections)? onDownload;

  @override
  State<PrescriptionOverviewCard> createState() =>
      _PrescriptionOverviewCardState();
}

class _PrescriptionOverviewCardState extends State<PrescriptionOverviewCard> {
  bool _exporting = false;

  Future<void> _download(List<PrescriptionSection> sections) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final handler = widget.onDownload;
      if (handler != null) {
        await handler(sections);
      } else {
        await downloadPrescriptionPdf(
          recipientName: widget.recipientName,
          sections: sections,
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('PDF তৈরি করা যায়নি। আবার চেষ্টা করুন।')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PrescriptionOverview>(
      future: widget.overview,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SukunSurface(
            tone: SukunSurfaceTone.soft,
            showBorder: false,
            child: Text('প্রেসক্রিপশনের তথ্য আনা যায়নি।'),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const SukunSurface(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SukunSurface(
              key: const Key('prescription-admin-section'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'সুকুনের দেওয়া আমল ও সাপ্লিমেন্ট',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (data.adminSections.isNotEmpty)
                        FilledButton.tonalIcon(
                          key: const Key('prescription-pdf-download'),
                          onPressed: _exporting
                              ? null
                              : () => _download(data.adminSections),
                          icon: _exporting
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('PDF'),
                        ),
                    ],
                  ),
                  const SizedBox(height: SukunSpace.md),
                  if (data.adminSections.isEmpty)
                    const Text('এখনো কোনো আমল বা সাপ্লিমেন্ট দেওয়া হয়নি।')
                  else
                    _Sections(sections: data.adminSections),
                ],
              ),
            ),
            if (data.selfSections.isNotEmpty) ...[
              const SizedBox(height: SukunSpace.md),
              SukunSurface(
                key: const Key('prescription-self-section'),
                tone: SukunSurfaceTone.soft,
                showBorder: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 20),
                        const SizedBox(width: SukunSpace.sm),
                        Expanded(
                          child: Text(
                            widget.selfLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'সুকুনের প্রেসক্রিপশনের বাইরে নিজের জন্য চালু করা রিমাইন্ডার।',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: SukunColors.muted),
                    ),
                    const SizedBox(height: SukunSpace.md),
                    _Sections(sections: data.selfSections),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Sections extends StatelessWidget {
  const _Sections({required this.sections});

  final List<PrescriptionSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          Text(
            section.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                for (var i = 0; i < section.entries.length; i++) ...[
                  if (i > 0) const TextSpan(text: '   '),
                  TextSpan(
                    text:
                        section.entries[i].instruction?.trim().isNotEmpty ==
                            true
                        ? '${section.entries[i].title}: '
                        : '${section.entries[i].title}।',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (section.entries[i].instruction?.trim().isNotEmpty == true)
                    TextSpan(text: section.entries[i].instruction!.trim()),
                ],
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: SukunSpace.md),
        ],
      ],
    );
  }
}
