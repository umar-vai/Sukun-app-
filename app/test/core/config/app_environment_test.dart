import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/config/app_environment.dart';

void main() {
  group('Supabase runtime configuration', () {
    test('accepts an unconfigured local preview', () {
      expect(
        () => validateSupabaseRuntimeConfiguration(
          environment: 'local',
          url: '',
          publishableKey: '',
        ),
        returnsNormally,
      );
    });

    test('requires URL and publishable key together', () {
      expect(
        () => validateSupabaseRuntimeConfiguration(
          environment: 'development',
          url: 'https://example.supabase.co',
          publishableKey: '',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects non-HTTPS backend URLs', () {
      expect(
        () => validateSupabaseRuntimeConfiguration(
          environment: 'development',
          url: 'http://example.supabase.co',
          publishableKey: 'sb_publishable_fixture',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('production is pinned to the approved project', () {
      expect(
        () => validateSupabaseRuntimeConfiguration(
          environment: 'production',
          url: AppEnvironment.productionSupabaseUrl,
          publishableKey: 'sb_publishable_fixture',
        ),
        returnsNormally,
      );
      expect(
        () => validateSupabaseRuntimeConfiguration(
          environment: 'production',
          url: 'https://wrong-project.supabase.co',
          publishableKey: 'sb_publishable_fixture',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('staging cannot silently start without Supabase', () {
      expect(
        () => validateSupabaseRuntimeConfiguration(
          environment: 'staging',
          url: '',
          publishableKey: '',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('production cannot silently start without Supabase', () {
      expect(
        () => validateSupabaseRuntimeConfiguration(
          environment: 'production',
          url: '',
          publishableKey: '',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Firebase client runtime configuration', () {
    test('allows notifications to remain unconfigured in local previews', () {
      expect(
        () => validateFirebaseRuntimeConfiguration(
          projectId: '',
          messagingSenderId: '',
          androidApiKey: '',
          androidAppId: '',
          iosApiKey: '',
          iosAppId: '',
        ),
        returnsNormally,
      );
    });

    test('accepts complete Android-only pilot configuration', () {
      expect(
        () => validateFirebaseRuntimeConfiguration(
          projectId: 'firebase-project',
          messagingSenderId: '123456',
          androidApiKey: 'android-public-key',
          androidAppId: 'android-app-id',
          iosApiKey: '',
          iosAppId: '',
        ),
        returnsNormally,
      );
    });

    test('rejects partial platform credentials', () {
      expect(
        () => validateFirebaseRuntimeConfiguration(
          projectId: 'firebase-project',
          messagingSenderId: '123456',
          androidApiKey: 'android-public-key',
          androidAppId: '',
          iosApiKey: '',
          iosAppId: '',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects missing shared Firebase project values', () {
      expect(
        () => validateFirebaseRuntimeConfiguration(
          projectId: '',
          messagingSenderId: '123456',
          androidApiKey: 'android-public-key',
          androidAppId: 'android-app-id',
          iosApiKey: '',
          iosAppId: '',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('accepts complete iOS-only configuration', () {
      expect(
        () => validateFirebaseRuntimeConfiguration(
          projectId: 'firebase-project',
          messagingSenderId: '123456',
          androidApiKey: '',
          androidAppId: '',
          iosApiKey: 'ios-public-key',
          iosAppId: 'ios-app-id',
        ),
        returnsNormally,
      );
    });
  });
}
