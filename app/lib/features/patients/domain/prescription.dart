enum PrescriptionVisibility {
  patient,
  staffOnly;

  String get databaseValue => switch (this) {
    PrescriptionVisibility.patient => 'patient',
    PrescriptionVisibility.staffOnly => 'staff_only',
  };

  String get label => switch (this) {
    PrescriptionVisibility.patient => 'Visible to patient',
    PrescriptionVisibility.staffOnly => 'Staff only',
  };

  static PrescriptionVisibility fromDatabase(String? value) {
    return value == 'staff_only'
        ? PrescriptionVisibility.staffOnly
        : PrescriptionVisibility.patient;
  }
}

class Prescription {
  const Prescription({
    required this.id,
    required this.patientId,
    required this.rawText,
    required this.visibility,
    required this.createdAt,
    this.sessionDate,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final sessionDate = json['session_date'] as String?;
    return Prescription(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      rawText: json['raw_text'] as String,
      visibility: PrescriptionVisibility.fromDatabase(
        json['visibility'] as String?,
      ),
      sessionDate: sessionDate == null ? null : DateTime.parse(sessionDate),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String patientId;
  final String rawText;
  final PrescriptionVisibility visibility;
  final DateTime? sessionDate;
  final DateTime createdAt;
}
