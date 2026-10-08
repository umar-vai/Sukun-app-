/// Only sent or opened SERVER notification events belong in this history.
/// Device-only reminders are not stored as server events and are not included.
class PatientInboxMessage {
  const PatientInboxMessage({
    required this.id,
    required this.type,
    required this.scheduledAt,
    required this.opened,
  });

  factory PatientInboxMessage.fromJson(Map<String, dynamic> json) =>
      PatientInboxMessage(
        id: json['id'] as String,
        type: json['notification_type'] as String,
        scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
        opened: json['status'] == 'opened' && json['opened_at'] != null,
      );

  final String id;
  final String type;
  final DateTime scheduledAt;
  final bool opened;

  PatientInboxMessage asOpened() => PatientInboxMessage(
    id: id,
    type: type,
    scheduledAt: scheduledAt,
    opened: true,
  );

  String get titleBn => switch (type) {
    'plan_updated' => 'আপনার পরিকল্পনায় পরিবর্তন এসেছে',
    'care_reminder' => 'নির্ধারিত কাজের কথা মনে করিয়ে দেওয়া',
    _ => 'সুকুন লাইফের বার্তা',
  };

  String get descriptionBn => switch (type) {
    'plan_updated' => 'আপনার বর্তমান পরিকল্পনাটি খুলে দেখুন।',
    'care_reminder' => 'আজকের করণীয়গুলো দেখে নিন।',
    _ => 'বিস্তারিত জানতে আপনার আজকের কাজগুলো দেখুন।',
  };

  String get safeTargetRoute =>
      type == 'plan_updated' ? '/patient/plan' : '/patient/home';
}

abstract interface class NotificationInboxRepository {
  Future<List<PatientInboxMessage>> getRecentMessages();
  Future<void> markOpened(String notificationId);
}

class PatientInboxException implements Exception {
  const PatientInboxException();
}
