import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/config/web_preview_config.dart';

void main() {
  group('public Pages web backend isolation', () {
    test('unconfigured local mode shows guest UI safely', () {
      expect(
        () => validateWebPreviewConfiguration(
          environment: 'local',
          url: '',
          publishableKey: '',
        ),
        returnsNormally,
      );
    });

    test('isolated staging can enable real patient/admin auth', () {
      expect(
        () => validateWebPreviewConfiguration(
          environment: 'staging',
          url: 'https://isolated-preview.supabase.co',
          publishableKey: 'sb_publishable_fixture',
        ),
        returnsNormally,
      );
    });

    test('production project forbidden even when staging is selected', () {
      expect(
        () => validateWebPreviewConfiguration(
          environment: 'staging',
          url: AppEnvironment.productionSupabaseUrl,
          publishableKey: 'sb_publishable_fixture',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('unconfigured local cannot silently target a backend', () {
      expect(
        () => validateWebPreviewConfiguration(
          environment: 'local',
          url: 'https://isolated-preview.supabase.co',
          publishableKey: 'sb_publishable_fixture',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('approved production backend accepts public browser key only', () {
      expect(
        () => validateWebPreviewConfiguration(
          environment: 'production',
          url: AppEnvironment.productionSupabaseUrl,
          publishableKey: 'sb_publishable_fixture',
        ),
        returnsNormally,
      );
      for (final key in ['sb_secret_not_allowed', 'eyJ.legacy_anon']) {
        expect(
          () => validateWebPreviewConfiguration(
            environment: 'production',
            url: AppEnvironment.productionSupabaseUrl,
            publishableKey: key,
          ),
          throwsA(isA<StateError>()),
        );
      }
    });

    test('production mode rejects any other project', () {
      expect(
        () => validateWebPreviewConfiguration(
          environment: 'production',
          url: 'https://isolated-preview.supabase.co',
          publishableKey: 'sb_publishable_fixture',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('local Pages rejects each enabled authentication feature', () {
      final attempts = <void Function()>[
        () => validateWebPreviewConfiguration(
          environment: 'local',
          url: '',
          publishableKey: '',
          publicMemberSignupEnabled: true,
        ),
        () => validateWebPreviewConfiguration(
          environment: 'local',
          url: '',
          publishableKey: '',
          emailOtpEnabled: true,
        ),
        () => validateWebPreviewConfiguration(
          environment: 'local',
          url: '',
          publishableKey: '',
          phoneOtpEnabled: true,
        ),
        () => validateWebPreviewConfiguration(
          environment: 'local',
          url: '',
          publishableKey: '',
          googleOAuthEnabled: true,
        ),
      ];
      for (final attempt in attempts) {
        expect(attempt, throwsA(isA<StateError>()));
      }
    });

    test(
      'configured staging accepts explicitly enabled auth feature flags',
      () {
        expect(
          () => validateWebPreviewConfiguration(
            environment: 'staging',
            url: 'https://isolated-preview.supabase.co',
            publishableKey: 'sb_publishable_fixture',
            publicMemberSignupEnabled: true,
            emailOtpEnabled: true,
            phoneOtpEnabled: true,
            googleOAuthEnabled: true,
          ),
          returnsNormally,
        );
      },
    );

    test('staging cannot silently downgrade to guest', () {
      expect(
        () => validateWebPreviewConfiguration(
          environment: 'staging',
          url: '',
          publishableKey: '',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('partial and non-Supabase configuration cannot start', () {
      expect(
        () => validateWebPreviewConfiguration(
          environment: 'staging',
          url: 'https://staging.supabase.co',
          publishableKey: '',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => validateWebPreviewConfiguration(
          environment: 'staging',
          url: 'https://example.com',
          publishableKey: 'sb_publishable_fixture',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
