import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/universal_announcements/data/announcement_repository.dart';

/// A re-published announcement is a new delivery; an unchanged publication
/// is shown at most once for each local guest or authenticated owner.
String? universalNoticePublicationKey(UniversalAnnouncement notice) {
  final published = notice.publishedAt;
  if (!notice.isPublished || published == null) return null;
  return '${notice.id}@${published.toUtc().toIso8601String()}';
}

UniversalAnnouncement? nextUnseenUniversalNotice(
  List<UniversalAnnouncement> notices,
  Set<String> seen,
) {
  for (final notice in notices) {
    final key = universalNoticePublicationKey(notice);
    if (key != null && !seen.contains(key)) return notice;
  }
  return null;
}

/// Public-announcement receipts contain only an account ID and notice IDs.
/// The server RLS policy independently enforces ownership; guests have no
/// account ID and use private per-browser/per-installation preferences.
class UniversalNoticeSeenStore {
  const UniversalNoticeSeenStore(this._client);
  final SupabaseClient? _client;

  static String storageKey(String? userId) => userId == null
      ? 'sukun_public_notice_seen_guest_v1'
      : 'sukun_public_notice_seen_user_${userId}_v1';

  Future<Set<String>> read(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(storageKey(userId))?.toSet() ?? <String>{};
    if (userId == null || _client == null) return seen;

    try {
      final rows = await _client
          .from('universal_notice_seen')
          .select('announcement_id,published_at')
          .eq('user_id', userId)
          .order('seen_at', ascending: false)
          .limit(500);
      for (final row in rows) {
        final id = row['announcement_id'] as String?;
        final published = DateTime.tryParse(
          row['published_at'] as String? ?? '',
        );
        if (id != null && published != null) {
          seen.add('$id@${published.toUtc().toIso8601String()}');
        }
      }
    } catch (_) {
      // A temporarily offline server must not trigger repeated popups on
      // this same installation. The local receipt remains authoritative here.
    }
    return seen;
  }

  Future<void> mark(UniversalAnnouncement notice, String? userId) async {
    final instanceKey = universalNoticePublicationKey(notice);
    if (instanceKey == null) return;

    // Persist before showing; a fast route change or browser reload cannot
    // accidentally replay the exact same public announcement on this device.
    final prefs = await SharedPreferences.getInstance();
    final key = storageKey(userId);
    final previous = prefs.getStringList(key) ?? <String>[];
    final all = <String>{...previous, instanceKey}.toList();
    await prefs.setStringList(
      key,
      all.length > 500 ? all.sublist(all.length - 500) : all,
    );

    if (userId == null || _client == null) return;
    try {
      await _client.from('universal_notice_seen').insert({
        'user_id': userId,
        'announcement_id': notice.id,
        'published_at': notice.publishedAt!.toUtc().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') {
        // The banner is still shown once locally when the server is offline
        // or this backward-compatible migration has not yet been deployed.
      }
    } catch (_) {
      // Offline fallback: the local once-only guarantee still holds.
    }
  }
}

final universalNoticeSeenStoreProvider = Provider<UniversalNoticeSeenStore>(
  (ref) => UniversalNoticeSeenStore(
    AppEnvironment.isSupabaseConfigured ? Supabase.instance.client : null,
  ),
);
