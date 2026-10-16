/// Native and unit-test fallback. Browser Notification APIs live in a
/// conditional web import so Android/iOS builds never depend on dart:html.
bool get supported => false;
bool get granted => false;
Future<bool> requestPermission() async => false;
void show({
  required String title,
  required String body,
  required void Function() onClick,
}) {}
