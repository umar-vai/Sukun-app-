import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/account/presentation/notification_health_settings_screen.dart';

void main() {
  test('browser diagnostics never equate permission with closed-tab push', () {
    expect(
      notificationPermissionHint(granted: true, isWeb: true),
      contains('Web Push'),
    );
    expect(
      notificationPermissionHint(granted: false, isWeb: true),
      contains('অনুমতি'),
    );
  });

  test('native diagnostics warn about phone battery restrictions', () {
    expect(
      notificationPermissionHint(granted: true, isWeb: false),
      contains('ব্যাটারি'),
    );
    expect(
      notificationPermissionHint(granted: false, isWeb: false),
      contains('অ্যাপ সেটিংস'),
    );
  });
}
