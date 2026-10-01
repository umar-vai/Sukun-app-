enum CarePlanStatus {
  draft,
  active,
  inactive,
  archived;

  static CarePlanStatus fromDatabase(String? value) {
    return CarePlanStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => CarePlanStatus.inactive,
    );
  }

  String get label => switch (this) {
    CarePlanStatus.draft => 'Draft',
    CarePlanStatus.active => 'Active',
    CarePlanStatus.inactive => 'Inactive',
    CarePlanStatus.archived => 'Archived',
  };
}

class CarePlan {
  const CarePlan({
    required this.id,
    required this.patientId,
    required this.version,
    required this.name,
    required this.startDate,
    required this.status,
    required this.createdAt,
    this.prescriptionId,
    this.endDate,
    this.publishedAt,
    this.archivedAt,
  });

  factory CarePlan.fromJson(Map<String, dynamic> json) {
    return CarePlan(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      prescriptionId: json['prescription_id'] as String?,
      version: json['version'] as int,
      name: json['name'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: _optionalDate(json['end_date']),
      status: CarePlanStatus.fromDatabase(json['status'] as String?),
      publishedAt: _optionalDate(json['published_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
      archivedAt: _optionalDate(json['archived_at']),
    );
  }

  final String id;
  final String patientId;
  final String? prescriptionId;
  final int version;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final CarePlanStatus status;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime? archivedAt;

  bool get isEditable => status == CarePlanStatus.draft;
  bool get canArchive =>
      status == CarePlanStatus.active || status == CarePlanStatus.inactive;
}

DateTime? _optionalDate(dynamic value) {
  return value is String ? DateTime.tryParse(value) : null;
}
