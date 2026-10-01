import 'package:flutter/material.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';

class PatientProgressScreen extends StatelessWidget {
  const PatientProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PatientScaffold(
      title: 'Progress',
      selectedIndex: 3,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Today’s completion is tracked securely. The multi-day adherence view is the next patient-care milestone.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
