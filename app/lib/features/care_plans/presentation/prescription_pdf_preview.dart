import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/domain/prescription_sections.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';

typedef PrescriptionPdfLine = ({
  String text,
  double size,
  bool heading,
  double gap,
});

List<PrescriptionPdfLine> prescriptionPdfLines({
  required CarePlan plan,
  required Patient patient,
  required List<PlanAction> actions,
  String? practitioner,
}) {
  if (patient.id != plan.patientId ||
      actions.any((action) => action.carePlanId != plan.id)) {
    throw ArgumentError(
      'Prescription records must belong to the same patient and plan.',
    );
  }
  final draft = plan.publishedAt == null || plan.isEditable;
  final sections = <String, List<PlanAction>>{
    for (final category in officialTemplateCategories) category.title: [],
    'অন্যান্য করণীয়': [],
  };
  for (final action in actions) {
    if (action.reviewStatus == ActionReviewStatus.rejected ||
        (!draft && action.reviewStatus != ActionReviewStatus.approved)) {
      continue;
    }
    sections[prescriptionCategory(action)]!.add(action);
  }

  PrescriptionPdfLine line(
    String text, {
    double size = 11,
    bool heading = false,
    double gap = 2,
  }) => (text: text, size: size, heading: heading, gap: gap);

  return [
    line(plan.name, size: 21, heading: true, gap: 6),
    line('রোগী  ${patient.fullName}  |  ${patient.patientCode}', size: 12),
    if (practitioner != null && practitioner.isNotEmpty)
      line('প্রস্তুতকারী  $practitioner'),
    line(
      'তারিখ  ${prescriptionDate(plan.publishedAt ?? plan.createdAt)}   |   সংস্করণ  ${plan.version}',
    ),
    if (draft) line('খসড়া | যাচাই ও অনুমোদন বাকি', heading: true),
    for (final section in sections.entries.where(
      (entry) => entry.value.isNotEmpty,
    )) ...[
      line(section.key, size: 15, heading: true, gap: 9),
      for (final action in section.value) ...[
        line(action.title, size: 13, heading: true, gap: 5),
        if (action.instruction?.trim().isNotEmpty == true)
          line(action.instruction!),
        line(
          [
            prescriptionFrequency(action.frequency),
            ?prescriptionWindow(action.timeWindow),
            if (action.exactTime case final time?) prescriptionTime(time),
            prescriptionDate(action.startDate),
            if (action.endDate case final end?) 'শেষ ${prescriptionDate(end)}',
            if (action.countTarget case final count?) '$count বার',
            if (action.durationMinutes case final minutes?) '$minutes মিনিট',
            if (action.reminderEnabled) 'রিমাইন্ডার চালু',
          ].join('  |  '),
          size: 10,
        ),
        for (final resource in action.linkedResources)
          line(
            [
              resource.titleBn ?? resource.title,
              ?resource.usageNote,
            ].join('  |  '),
            size: 10,
          ),
      ],
    ],
  ];
}

/// The Flutter text engine performs OpenType shaping and bidi layout. We
/// render each page at 216 dpi so native and web exports preserve those glyphs.
Future<Uint8List> renderPrescriptionPdf({
  required CarePlan plan,
  required Patient patient,
  required List<PlanAction> actions,
  String? practitioner,
}) async {
  const page = PdfPageFormat.a4;
  const margin = 40.0;
  const top = 100.0;
  final bottom = page.height - 65;
  final width = page.width - margin * 2;
  const scale = 3.0;
  const navy = Color(0xff0d2b45);
  const tide = Color(0xff0a70a8);
  final document = pw.Document(
    title: 'Sukun Life Prescription',
    author: 'Sukun Life',
  );
  final pageImages = <pw.MemoryImage>[];
  final logoData = await rootBundle.load('assets/brand/sukunlife_logo.png');
  final logo = await ui
      .instantiateImageCodec(logoData.buffer.asUint8List())
      .then((codec) async {
        try {
          return (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      });

  TextPainter layout(String text, double size, Color color, double maxWidth) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'SukunLiAdorNoirrit',
            color: color,
            fontSize: size,
            height: 1.35,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

  late ui.PictureRecorder recorder;
  late Canvas canvas;
  var y = top;

  void startPage() {
    recorder = ui.PictureRecorder();
    canvas = Canvas(recorder)..scale(scale);
    canvas.drawColor(Colors.white, BlendMode.src);
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(logo.width.toDouble(), logo.height.toDouble()),
      const Size(112, 65),
    );
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      Rect.fromLTWH(
        margin,
        12,
        fitted.destination.width,
        fitted.destination.height,
      ),
      Paint()..filterQuality = FilterQuality.high,
    );
    final status = layout(
      plan.publishedAt == null || plan.isEditable
          ? 'DRAFT | খসড়া'
          : 'অনুমোদিত প্রেসক্রিপশন',
      13,
      tide,
      width,
    );
    status.paint(canvas, Offset(page.width - margin - status.width, 45));
    status.dispose();
    canvas.drawLine(
      const Offset(margin, 82),
      Offset(page.width - margin, 82),
      Paint()
        ..color = tide
        ..strokeWidth = 1,
    );
    y = top;
  }

  Future<void> finishPage() async {
    final footer = layout('Sukun Life | ব্যক্তিগত ও গোপনীয়', 9, navy, width);
    footer.paint(canvas, Offset(margin, page.height - 43));
    footer.dispose();

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (page.width * scale).ceil(),
      (page.height * scale).ceil(),
    );
    picture.dispose();
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('Unable to render prescription page.');
      final pageImage = pw.MemoryImage(png.buffer.asUint8List());
      pageImages.add(pageImage);
    } finally {
      image.dispose();
    }
  }

  startPage();
  try {
    final lines = prescriptionPdfLines(
      plan: plan,
      patient: patient,
      actions: actions,
      practitioner: practitioner,
    );
    for (final line in lines) {
      final paragraph = layout(
        line.text,
        line.size,
        line.heading ? tide : navy,
        width,
      );
      try {
        final metrics = paragraph.computeLineMetrics();
        y += line.gap;
        for (final (index, metric) in metrics.indexed) {
          final lineTop = index == 0
              ? 0.0
              : metrics[index - 1].baseline + metrics[index - 1].descent;
          final lineBottom = index == metrics.length - 1
              ? paragraph.height
              : metric.baseline + metric.descent;
          final lineHeight = lineBottom - lineTop;
          if (y + lineHeight > bottom) {
            await finishPage();
            startPage();
          }
          canvas.save();
          canvas.clipRect(Rect.fromLTWH(margin, y, width, lineHeight));
          paragraph.paint(canvas, Offset(margin, y - lineTop));
          canvas.restore();
          y += lineHeight;
        }
      } finally {
        paragraph.dispose();
      }
    }
    await finishPage();
    for (final (index, pageImage) in pageImages.indexed) {
      document.addPage(
        pw.Page(
          pageFormat: page,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              pw.Image(
                pageImage,
                width: page.width,
                height: page.height,
                fit: pw.BoxFit.fill,
              ),
              pw.Positioned(
                bottom: 32,
                right: margin,
                child: pw.Text(
                  '${index + 1} / ${pageImages.length}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromInt(0xff0d2b45),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return await document.save();
  } finally {
    if (recorder.isRecording) recorder.endRecording().dispose();
    logo.dispose();
  }
}

class PrescriptionPdfPreview extends StatefulWidget {
  const PrescriptionPdfPreview({
    super.key,
    required this.plan,
    required this.patient,
    required this.actions,
    this.practitioner,
  });

  final CarePlan plan;
  final Patient patient;
  final List<PlanAction> actions;
  final String? practitioner;

  @override
  State<PrescriptionPdfPreview> createState() => _PrescriptionPdfPreviewState();
}

class _PrescriptionPdfPreviewState extends State<PrescriptionPdfPreview> {
  late Future<Uint8List> _document = _generate();
  bool _working = false;

  Future<Uint8List> _generate() => renderPrescriptionPdf(
    plan: widget.plan,
    patient: widget.patient,
    actions: widget.actions,
    practitioner: widget.practitioner,
  );

  Future<void> _output(Uint8List bytes, {required bool print}) async {
    final label = widget.plan.publishedAt == null ? 'draft' : 'approved';
    final filename = 'sukun-prescription-v${widget.plan.version}-$label.pdf';
    setState(() => _working = true);
    try {
      if (print) {
        await Printing.layoutPdf(
          name: filename,
          format: PdfPageFormat.a4,
          dynamicLayout: false,
          onLayout: (_) => bytes,
        );
      } else {
        await FilePicker.saveFile(fileName: filename, bytes: bytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF রপ্তানি করা যায়নি। আবার চেষ্টা করুন।'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _document,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.plan.publishedAt == null
                ? 'Draft Prescription PDF'
                : 'Approved Prescription PDF',
          ),
          actions: [
            IconButton(
              tooltip: 'Download PDF',
              onPressed: bytes == null || _working
                  ? null
                  : () => _output(bytes, print: false),
              icon: const Icon(Icons.download_outlined),
            ),
            IconButton(
              tooltip: 'Print PDF',
              onPressed: bytes == null || _working
                  ? null
                  : () => _output(bytes, print: true),
              icon: const Icon(Icons.print_outlined),
            ),
          ],
        ),
        body: snapshot.hasError
            ? AppErrorState(
                message: 'প্রেসক্রিপশনের PDF তৈরি করা যায়নি।',
                onRetry: () => setState(() => _document = _generate()),
              )
            : bytes == null
            ? const AppLoadingState(label: 'PDF তৈরি হচ্ছে…')
            : PdfViewer.data(
                bytes,
                sourceName:
                    'prescription-${widget.plan.id}-${identityHashCode(bytes)}',
              ),
      );
    },
  );
}
