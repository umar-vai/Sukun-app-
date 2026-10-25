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

    test('staging runtime is pinned to the synthetic Sukun project', () {
      expect(
        () => validateSupabaseRuntimeConfiguration(
          environment: 'staging',
          url: AppEnvironment.stagingSupabaseUrl,
          publishableKey: 'sb_publishable_fixture',
        ),
        returnsNormally,
      );
      for (final url in [
        'https://another-preview.supabase.co',
        AppEnvironment.productionSupabaseUrl,
      ]) {
        expect(
          () => validateSupabaseRuntimeConfiguration(
            environment: 'staging',
            url: url,
            publishableKey: 'sb_publishable_fixture',
          ),
          throwsA(isA<StateError>()),
        );
      }
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

    test('allows complete Android-only FCM pilot without iOS config', () {
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

    test('rejects partially configured Android and iOS FCM clients', () {
      for (final badConfig in [
        ('android-public-key', '', '', ''),
        ('', 'android-app-id', '', ''),
        ('android-public-key', 'android-app-id', 'ios-key', ''),
        ('', '', '', ''),
      ]) {
        final missingShared = badConfig == ('', '', '', '');
        expect(
          () => validateFirebaseRuntimeConfiguration(
            projectId: missingShared ? '' : 'firebase-project',
            messagingSenderId: missingShared ? '' : '123456',
            androidApiKey: badConfig.$1,
            androidAppId: badConfig.$2,
            iosApiKey: badConfig.$3,
            iosAppId: badConfig.$4,
          ),
          missingShared ? returnsNormally : throwsA(isA<StateError>()),
        );
      }
    });
  });
}
