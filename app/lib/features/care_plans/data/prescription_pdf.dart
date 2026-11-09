import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/prescription_summary.dart';

/// Builds a printable A4 prescription.
///
/// Pages are drawn with Flutter's own text engine and the bundled Bangla
/// font, then placed in the PDF as images. PDF text engines do not shape
/// Bangla conjuncts correctly, so this keeps every letter exactly as it
/// looks in the app. Times are not printed; only what was given, by section.
class PrescriptionPdfBuilder {
  const PrescriptionPdfBuilder({
    this.fontFamily = 'SukunLiAdorNoirrit',
    this.pixelRatio = 2.5,
  });

  final String fontFamily;
  final double pixelRatio;

  static const _pageWidth = 595.0; // A4 in PDF points
  static const _pageHeight = 842.0;
  static const _margin = 48.0;
  static const _footerSpace = 36.0;
  static const _contentWidth = _pageWidth - _margin * 2;

  TextStyle get _body => TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    height: 1.7,
    color: SukunColors.nightNavy,
  );

  TextStyle get _heading => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: SukunColors.deepTide,
  );

  TextStyle get _small => TextStyle(
    fontFamily: fontFamily,
    fontSize: 9.5,
    height: 1.4,
    color: SukunColors.muted,
  );

  TextPainter _paragraph(List<PrescriptionEntry> entries) {
    final spans = <InlineSpan>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final instruction = entry.instruction?.trim();
      if (i > 0) spans.add(const TextSpan(text: '   '));
      spans.add(
        TextSpan(
          text: instruction == null || instruction.isEmpty
              ? '${entry.title}।'
              : '${entry.title}: ',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      if (instruction != null && instruction.isNotEmpty) {
        spans.add(TextSpan(text: instruction));
      }
    }
    return TextPainter(
      text: TextSpan(style: _body, children: spans),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
    )..layout(maxWidth: _contentWidth);
  }

  TextPainter _text(String text, TextStyle style, {double? width}) =>
      TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width ?? _contentWidth);

  /// Splits sections into pages. Each block is a heading or a run of
  /// entries; a section that does not fit continues on the next page.
  List<List<_Block>> _paginate(
    List<PrescriptionSection> sections,
    double firstPageTop,
  ) {
    const bottom = _pageHeight - _margin - _footerSpace;
    final pages = <List<_Block>>[[]];
    var y = firstPageTop;

    void newPage() {
      pages.add([]);
      y = _margin;
    }

    for (final section in sections) {
      var remaining = List.of(section.entries);
      var continued = false;
      while (remaining.isNotEmpty) {
        final heading = _text(
          continued ? '${section.title} (চলমান)' : section.title,
          _heading,
        );
        final headingHeight = heading.height + 6;
        // Keep a heading together with at least a few lines of its text.
        if (y + headingHeight + _body.fontSize! * 3.5 > bottom &&
            pages.last.isNotEmpty) {
          newPage();
        }
        var take = remaining.length;
        var painter = _paragraph(remaining);
        while (take > 1 && y + headingHeight + painter.height > bottom) {
          take--;
          painter = _paragraph(remaining.sublist(0, take));
        }
        pages.last.add(_Block.heading(heading, y));
        y += headingHeight;
        pages.last.add(_Block.paragraph(painter, y));
        y += painter.height + 18;
        remaining = remaining.sublist(take);
        continued = true;
        if (remaining.isNotEmpty) newPage();
      }
    }
    return pages;
  }

  Future<ui.Image?> _logo() async {
    try {
      final data = await rootBundle.load(BrandAssets.officialLogo);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  /// Returns one PNG per A4 page.
  Future<List<Uint8List>> renderPages({
    required String recipientName,
    required List<PrescriptionSection> sections,
    DateTime? date,
  }) async {
    final logo = await _logo();
    final day = date ?? DateTime.now();
    final title = _text(
      'প্রেসক্রিপশন ও করণীয়',
      _heading.copyWith(fontSize: 18),
    );
    final nameLine = _text(
      'নাম: $recipientName',
      _body.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
    );
    final dateLine = _text(
      'তারিখ: ${toBanglaDigits('${day.day}/${day.month}/${day.year}')}',
      _small.copyWith(fontSize: 11),
    );
    const logoHeight = 54.0;
    final headerBottom =
        _margin + logoHeight + 14 + nameLine.height + 4 + dateLine.height + 16;
    final pages = _paginate(sections, headerBottom + 18);
    final result = <Uint8List>[];

    for (var index = 0; index < pages.length; index++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(pixelRatio);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _pageWidth, _pageHeight),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      if (index == 0) {
        if (logo != null) {
          final width = logo.width * logoHeight / logo.height;
          paintImage(
            canvas: canvas,
            rect: Rect.fromLTWH(_margin, _margin, width, logoHeight),
            image: logo,
            filterQuality: FilterQuality.high,
          );
        }
        title.paint(
          canvas,
          Offset(
            _pageWidth - _margin - title.width,
            _margin + (logoHeight - title.height) / 2,
          ),
        );
        var y = _margin + logoHeight + 14;
        nameLine.paint(canvas, Offset(_margin, y));
        y += nameLine.height + 4;
        dateLine.paint(canvas, Offset(_margin, y));
        y += dateLine.height + 12;
        canvas.drawRect(
          Rect.fromLTWH(_margin, y, _contentWidth, 2),
          Paint()..color = SukunColors.sukunBlue,
        );
      }
      for (final block in pages[index]) {
        block.painter.paint(canvas, Offset(_margin, block.top));
      }
      final footer = _text(
        'Sukun Life · পৃষ্ঠা ${toBanglaDigits('${index + 1}')}/'
        '${toBanglaDigits('${pages.length}')}',
        _small,
      );
      canvas.drawRect(
        Rect.fromLTWH(_margin, _pageHeight - _margin - 14, _contentWidth, 0.6),
        Paint()..color = SukunColors.border,
      );
      footer.paint(
        canvas,
        Offset((_pageWidth - footer.width) / 2, _pageHeight - _margin - 6),
      );
      final image = await recorder.endRecording().toImage(
        (_pageWidth * pixelRatio).round(),
        (_pageHeight * pixelRatio).round(),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      result.add(png!.buffer.asUint8List());
    }
    return result;
  }

  Future<Uint8List> build({
    required String recipientName,
    required List<PrescriptionSection> sections,
    DateTime? date,
  }) async {
    final pages = await renderPages(
      recipientName: recipientName,
      sections: sections,
      date: date,
    );
    final document = pw.Document(
      title: 'Sukun Life prescription',
      author: 'Sukun Life',
    );
    for (final png in pages) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill),
        ),
      );
    }
    return document.save();
  }
}

final class _Block {
  _Block.heading(this.painter, this.top);
  _Block.paragraph(this.painter, this.top);

  final TextPainter painter;
  final double top;
}

/// Builds the PDF and hands it to the platform: a download in the browser,
/// the share/save sheet on phones.
Future<void> downloadPrescriptionPdf({
  required String recipientName,
  required List<PrescriptionSection> sections,
}) async {
  final bytes = await const PrescriptionPdfBuilder().build(
    recipientName: recipientName,
    sections: sections,
  );
  final safe = recipientName
      .replaceAll(RegExp(r'[^A-Za-z0-9ঀ-৿]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'sukun-prescription${safe.isEmpty ? '' : '-$safe'}.pdf',
  );
}
