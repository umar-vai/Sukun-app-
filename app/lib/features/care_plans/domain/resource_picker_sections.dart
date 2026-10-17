import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';

/// Keep the Admin picker aligned with the eight public Resources sections.
/// The picker may also show unpublished items to explain why they cannot be
/// linked; this grouping does not change database visibility or linkability.
bool resourceMatchesPickerSection(
  ContentResourceOption resource,
  ResourceSection section,
) {
  // These book-derived excerpts are deliberately outside public CMS browsing.
  if (resource.isEditorialRuqyahExcerpt) return false;
  if (!section.types.contains(resource.type)) return false;
  if (section.categoryPrefixes.isEmpty) return true;

  final slug = resource.categorySlug;
  if (slug != null &&
      section.categoryPrefixes.any(
        (prefix) => slug == prefix || slug.startsWith('$prefix-'),
      )) {
    return true;
  }
  // Published imported duas without category IDs appear in public Dua & Azkar.
  return slug == null &&
      section.categoryPrefixes.contains('dua') &&
      (resource.type == 'dua' || resource.type == 'amal');
}

bool resourceMatchesAnyPickerSection(ContentResourceOption resource) =>
    resourceSections.any(
      (section) => resourceMatchesPickerSection(resource, section),
    );
