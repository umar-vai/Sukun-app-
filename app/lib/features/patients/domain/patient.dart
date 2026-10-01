enum PatientStatus {
  active,
  inactive,
  archived;

  static PatientStatus fromDatabase(String? value) {
    return PatientStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PatientStatus.inactive,
    );
  }
}

class Patient {
  const Patient({
    required this.id,
    required this.userId,
    required this.patientCode,
    required this.fullName,
    required this.status,
    required this.createdAt,
    this.phone,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      patientCode: json['patient_code'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      status: PatientStatus.fromDatabase(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String? userId;
  final String patientCode;
  final String fullName;
  final String? phone;
  final PatientStatus status;
  final DateTime createdAt;
}
