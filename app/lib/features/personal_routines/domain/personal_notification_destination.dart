/// A notification only carries an owner-scoped action UUID. Never trust its
/// payload as a media URL. The action's resources are fetched through RLS first.
///
/// If no verified/public playable or readable resource is linked, open the
/// user's own Today Routine checklist instead of an empty detail screen.
String personalNotificationDestination(List<Map<String, dynamic>> references) {
  for (final reference in references) {
    final provider = reference['provider'];
    if (provider == 'cms') {
      final raw = reference['content_items'];
      if (raw is! Map) continue;
      final cms = Map<String, dynamic>.from(raw);
      final id = reference['content_item_id'];
      if (id is! String ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(id)) {
        continue;
      }
      if (cms['id'] != id ||
          cms['status'] != 'published' ||
          cms['visibility'] != 'public') {
        continue;
      }
      return '/resources/${Uri.encodeComponent(id)}';
    }
    if (provider == 'quran') {
      final referenceId = reference['external_resource_ref'];
      if (referenceId is! String) continue;
      final parts = referenceId.split(':');
      if (parts.length != 2 && parts.length != 3) continue;
      if (parts.first != 'quran') continue;
      final surah = int.tryParse(parts[1]);
      final ayah = parts.length == 3 ? int.tryParse(parts[2]) : null;
      if (surah == null ||
          surah < 1 ||
          surah > 114 ||
          (parts.length == 3 && (ayah == null || ayah < 1 || ayah > 286))) {
        continue;
      }
      return '/resources/quran/$surah${ayah == null ? '' : '?ayah=$ayah'}';
    }
  }
  return '/my-routines?tab=today';
}
