import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/notifications/local_notifications_gateway.dart';

void main() {
  const publicPath =
      '/storage/v1/object/public/sukun-announcement-images/notices/qa-rich-a1b2.png';

  test('only configured staging and production public notice artwork is accepted', () {
    expect(
      isApprovedUniversalNoticeImageUrl(
        AppEnvironment.stagingSupabaseUrl + publicPath,
        backendUrl: AppEnvironment.stagingSupabaseUrl,
      ),
      isTrue,
    );
    expect(
      isApprovedUniversalNoticeImageUrl(
        AppEnvironment.productionSupabaseUrl + publicPath,
        backendUrl: AppEnvironment.productionSupabaseUrl,
      ),
      isTrue,
    );
    expect(
      isApprovedUniversalNoticeImageUrl(
        AppEnvironment.productionSupabaseUrl + publicPath,
        backendUrl: AppEnvironment.stagingSupabaseUrl,
      ),
      isFalse,
    );
  });

  test('push payload URLs cannot fetch unrelated hosts or patient assets', () {
    const staging = AppEnvironment.stagingSupabaseUrl;
    for (final unsafe in <String?>[
      null,
      '',
      'https://evil.example' + publicPath,
      'https://qacklgqvxvjjzsimjoip.supabase.co.evil.example' + publicPath,
      'http://qacklgqvxvjjzsimjoip.supabase.co' + publicPath,
      'https://evil.example@qacklgqvxvjjzsimjoip.supabase.co' + publicPath,
      'https://qacklgqvxvjjzsimjoip.supabase.co:444' + publicPath,
      '$staging$publicPath?download=1',
      '$staging$publicPath#track',
      '$staging/storage/v1/object/public/patient-attachments/notices/x.png',
      '$staging/storage/v1/object/sign/sukun-announcement-images/notices/x.png',
      '$staging/storage/v1/object/public/sukun-announcement-images/notices/../secrets.png',
      '$staging/storage/v1/object/public/sukun-announcement-images/notices/file.svg',
      '$staging/storage/v1/object/public/sukun-announcement-images/notices/nested/pixel.png',
    ]) {
      expect(
        isApprovedUniversalNoticeImageUrl(unsafe, backendUrl: staging),
        isFalse,
        reason: 'Rejected any untrusted artwork source',
      );
    }
    expect(
      isApprovedUniversalNoticeImageUrl(
        staging + publicPath,
        backendUrl: 'https://unapproved.supabase.co',
      ),
      isFalse,
    );
  });
}
