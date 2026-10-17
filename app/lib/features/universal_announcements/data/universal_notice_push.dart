import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/config/app_environment.dart';

/// Separate public opt-in topic. Never use this for patient-specific content.
/// Web browser-closed delivery requires its own verified VAPID/token gateway.
abstract final class UniversalNoticePush {
  static const topic = 'sukun_public_notices_v1';
  static const preference = 'sukun_public_notice_push_opt_in';

  static bool get supported => !kIsWeb && AppEnvironment.isFirebaseConfigured;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(preference) ?? false;
  }

  static Future<bool> enable() async {
    if (!supported) return false;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preference, true);
    return true;
  }

  static Future<void> disable() async {
    if (supported) {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preference, false);
  }
}

/// Only a validated public notice UUID may be turned into a navigation route.
/// FCM payload values are never trusted as arbitrary paths or external URLs.
String? universalNoticeIdFromPush(Map<String, dynamic> data) {
  if (data['type'] != 'universal_announcement') return null;
  final id = data['announcement_id'];
  if (id is! String) return null;
  final validUuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  return validUuid.hasMatch(id) ? id.toLowerCase() : null;
}
