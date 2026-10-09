import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/config/web_preview_config.dart';

void main() {
  group('public Pages preview isolation', () {
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

    test('a configured local or production preview is forbidden', () {
      for (final environment in ['local', 'production']) {
        expect(
          () => validateWebPreviewConfiguration(
            environment: environment,
            url: 'https://isolated-preview.supabase.co',
            publishableKey: 'sb_publishable_fixture',
          ),
          throwsA(isA<StateError>()),
        );
      }
    });

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
