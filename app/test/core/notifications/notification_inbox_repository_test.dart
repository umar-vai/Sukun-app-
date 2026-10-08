import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/notifications/notification_inbox_repository.dart';

void main() {
  test('parses only safe fields from server sent events', () {
    final message = PatientInboxMessage.fromJson({
      'id': 'event-1',
      'notification_type': 'care_reminder',
      'scheduled_at': '2026-10-08T08:00:00Z',
      'status': 'sent',
      'opened_at': null,
    });

    expect(message.opened, isFalse);
    expect(message.titleBn, 'নির্ধারিত কাজের কথা মনে করিয়ে দেওয়া');
    expect(message.safeTargetRoute, '/patient/home');
    expect(message.asOpened().opened, isTrue);
  });

  test('plan changes navigate only within the patient app', () {
    final message = PatientInboxMessage(
      id: 'event-2',
      type: 'plan_updated',
      scheduledAt: DateTime.utc(2026, 10, 8),
      opened: true,
    );

    expect(message.safeTargetRoute, '/patient/plan');
    expect(message.descriptionBn, contains('পরিকল্পনা'));
  });

  test('unknown event types never become arbitrary deep links', () {
    final message = PatientInboxMessage(
      id: 'event-3',
      type: 'https://attacker.example/internal?token=abc',
      scheduledAt: DateTime.utc(2026, 10, 8),
      opened: false,
    );

    expect(message.safeTargetRoute, '/patient/home');
    expect(message.titleBn, 'সুকুন লাইফের বার্তা');
    expect(message.titleBn, isNot(contains('attacker')));
  });
}
