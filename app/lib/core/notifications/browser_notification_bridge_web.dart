// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Browser notifications work only with permission on HTTPS. The tab must
/// remain running to fire local timers; closed-tab push requires a separately
/// configured FCM service worker and backend delivery, not this adapter.
bool get supported => html.Notification.supported;
bool get granted => supported && html.Notification.permission == 'granted';

Future<bool> requestPermission() async {
  if (!supported) return false;
  if (granted) return true;
  try {
    final result = await html.Notification.requestPermission();
    return result == 'granted';
  } on Object {
    // Incognito, embedded WebViews and enterprise browser policies can deny
    // access without displaying a permission prompt.
    return false;
  }
}

void show({
  required String title,
  required String body,
  required void Function() onClick,
}) {
  if (!granted) return;
  final notification = html.Notification(title, body: body);
  notification.onClick.listen((_) {
    notification.close();
    onClick();
  });
}
