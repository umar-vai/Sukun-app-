import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/presentation/prescription_pdf_preview.dart';

import 'prescription_pdf_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('historical approved export uses exact instruction and schedule', () {
    final lines = prescriptionPdfLines(
      plan: pdfFixturePlan,
      patient: pdfFixturePatient,
      actions: pdfFixtureActions,
    ).map((line) => line.text);
    expect(lines, contains(pdfFixtureInstruction));
    expect(lines, contains('বিশেষ আমল'));
    expect(lines, contains('বিশেষ করণীয় included'));
    expect(lines, isNot(contains('বিশেষ করণীয় excluded')));
    expect(
      lines.any((line) => line.contains('বৃহস্পতি') && line.contains('08:15')),
      isTrue,
    );
  });

  test('generates private A4 PDF bytes from shaped Flutter text', () async {
    final loader = FontLoader('SukunLiAdorNoirrit')
      ..addFont(
        rootBundle.load(
          'assets/fonts/li_ador_noirrit/Li Ador Noirrit Regular.ttf',
        ),
      );
    await loader.load();
    final document = await renderPrescriptionPdf(
      plan: pdfFixturePlan,
      patient: pdfFixturePatient,
      actions: pdfFixtureActions,
    );
    final pdf = latin1.decode(document.bytes);
    expect(pdf, startsWith('%PDF-'));
    expect(pdf, contains('/MediaBox'));
    expect(pdf.contains('/Subtype/Image'), isTrue);
    expect(document.pages, hasLength(1));
    expect(document.pages.single.take(4), [137, 80, 78, 71]);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
