import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/notifications/notification_tap_relay.dart';

void main() {
  const uuid = 'a4ba5d60-81df-4688-81c8-b1064f7cf45e';

  test('reminder opens only a well-formed patient task route', () {
    expect(careTaskIdFromPayload('care_task:$uuid'), uuid);
    expect(
      patientTodayTaskRoute(uuid),
      '/patient/today?task=$uuid',
    );
  });

  test('never accepts raw URLs, fake task IDs, or arbitrary push copy', () {
    for (final unsafe in [
      null,
      '',
      'https://evil.test/phishing',
      '/admin/dashboard',
      'care_task:../../admin',
      'care_task:not-a-real-uuid',
      'care_task:$uuid?redirect=evil',
      'plan_updated',
    ]) {
      expect(careTaskIdFromPayload(unsafe), isNull);
    }
  });

  test('a tap persists until the verified patient session consumes it', () {
    final relay = NotificationTapRelay();
    relay.accept('care_task:$uuid');
    expect(relay.takePending(), uuid);
    expect(relay.takePending(), isNull);
    relay.accept('care_task:unsafe');
    expect(relay.takePending(), isNull);
    relay.dispose();
  });
}
