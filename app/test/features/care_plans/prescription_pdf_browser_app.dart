import 'package:flutter/material.dart';
import 'package:sukun_life/features/care_plans/presentation/prescription_pdf_preview.dart';

import 'prescription_pdf_fixture.dart';

void main() => runApp(
  MaterialApp(
    home: PrescriptionPdfPreview(
      plan: pdfFixturePlan,
      patient: pdfFixturePatient,
      actions: pdfFixtureActions,
    ),
  ),
);
