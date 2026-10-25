import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/universal_announcements/data/universal_notice_push.dart';

void main() {
  test(
    'only staging Android debug with Firebase config can copy FCM token',
    () {
      expect(
        canCopyStagingFcmToken(
          isWeb: false,
          isDebug: true,
          isAndroid: true,
          isFirebaseConfigured: true,
          environment: 'staging',
        ),
        isTrue,
      );

      for (final environment in ['production', 'development', 'local']) {
        expect(
          canCopyStagingFcmToken(
            isWeb: false,
            isDebug: true,
            isAndroid: true,
            isFirebaseConfigured: true,
            environment: environment,
          ),
          isFalse,
        );
      }
    },
  );

  test('deny web, release, non-Android and missing Firebase config', () {
    const variants = <({bool web, bool debug, bool android, bool firebase})>[
      (web: true, debug: true, android: true, firebase: true),
      (web: false, debug: false, android: true, firebase: true),
      (web: false, debug: true, android: false, firebase: true),
      (web: false, debug: true, android: true, firebase: false),
    ];

    for (final variant in variants) {
      expect(
        canCopyStagingFcmToken(
          isWeb: variant.web,
          isDebug: variant.debug,
          isAndroid: variant.android,
          isFirebaseConfigured: variant.firebase,
          environment: 'staging',
        ),
        isFalse,
      );
    }
  });
}
