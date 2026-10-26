import 'package:flutter/foundation.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/core/notifications/push_messaging_gateway.dart';
import 'package:sukun_life/features/universal_announcements/data/universal_notice_push.dart';

/// A device-local, process-only diagnostic for an explicitly authorized
/// staging debug APK. No identifiers, tokens, message bodies or URLs are kept.
abstract final class PublicNoticeTapQaDiagnostics {
  static bool get enabled => kDebugMode && AppEnvironment.name == 'staging';

  static final ValueNotifier<String> status = ValueNotifier<String>(
    'এখনো কোনো Push ট্যাপ পাওয়া যায়নি।',
  );

  static void record(RemotePushMessage message) {
    if (!enabled) return;
    if (message.type != 'universal_announcement') {
      status.value = 'Push ট্যাপ এসেছে, কিন্তু নোটিশের Type নেই।';
      return;
    }
    final validId = universalNoticeIdFromPush({
      'type': message.type,
      'announcement_id': message.announcementId,
    });
    status.value = validId == null
        ? 'Push ট্যাপ এসেছে, কিন্তু Notice ID পাওয়া যায়নি।'
        : 'Push ট্যাপ শনাক্ত হয়েছে; নোটিশ খোলার চেষ্টা চলছে।';
  }

  static void routeRequested() {
    if (!enabled) return;
    status.value = 'নোটিশের স্ক্রিন খোলার নির্দেশ পাঠানো হয়েছে।';
  }
}
