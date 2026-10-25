import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/notifications/notification_tap_relay.dart';

void main() {
  test('only verified public UUID can route local rich notice taps', () {
    const id = 'a1b2c3d4-a123-4fff-8aaa-123456789abc';
    expect(universalNoticeIdFromLocalPayload('universal_notice:$id'), id);
    expect(
      universalNoticeIdFromLocalPayload('universal_notice:javascript:foo'),
      isNull,
    );
    final relay = NotificationTapRelay();
    relay.accept('universal_notice:$id');
    expect(relay.takePendingUniversalNotice(), id);
    expect(relay.takePendingUniversalNotice(), isNull);
    relay.dispose();
  });

  const uuid = 'a4ba5d60-81df-4688-81c8-b1064f7cf45e';

  test('reminder opens only a well-formed patient task route', () {
    expect(careTaskIdFromPayload('care_task:$uuid'), uuid);
    expect(patientTodayTaskRoute(uuid), '/patient/today?task=$uuid');
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
  test('personal action tap is parsed as an owner-checked internal route', () {
    final relay = NotificationTapRelay();
    relay.accept('personal_action:$uuid');
    expect(relay.takePendingPersonalAction(), uuid);
    expect(relay.takePendingPersonalAction(), isNull);
    expect(personalActionRoute(uuid), '/my-routines/action/$uuid');
    expect(relay.takePending(), isNull);
    relay.dispose();
  });

  test('personal action tap rejects external URLs and ambiguous IDs', () {
    for (final unsafe in [
      null,
      'personal_action:https://evil.test',
      'personal_action:../../admin',
      'personal_action:$uuid?redirect=evil',
      'personal_action:bad-uuid',
    ]) {
      expect(personalActionIdFromPayload(unsafe), isNull);
    }
  });
}
