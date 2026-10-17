import 'package:sukun_life/features/resources/domain/content_resource.dart';

/// Suggests editable wording only for a verified public CMS selection.
/// It does not create a routine, send notifications or bypass RLS.
class PersonalRoutineResourcePrefill {
  const PersonalRoutineResourcePrefill({
    required this.contentId,
    required this.actionTitle,
    required this.notificationTitle,
  });

  final String contentId;
  final String actionTitle;
  final String notificationTitle;

  static PersonalRoutineResourcePrefill? fromResource(
    ContentResource? resource,
  ) {
    if (resource == null ||
        resource.status != 'published' ||
        resource.visibility != 'public') {
      return null;
    }
    final bangla = resource.titleBn?.trim() ?? '';
    final title = bangla.isNotEmpty ? bangla : resource.title.trim();
    if (title.isEmpty) return null;
    return PersonalRoutineResourcePrefill(
      contentId: resource.id,
      actionTitle: title,
      notificationTitle: 'আজকের করণীয়: $title',
    );
  }
}
