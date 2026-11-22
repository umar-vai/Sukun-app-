import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:sukun_life/features/resources/domain/resource_search.dart';

/// Search record for a published resource: its title, the category and
/// navigation group it lives in, its type words and short metadata.
SearchDocument<ContentResource> resourceSearchDocument(
  ContentResource resource,
) {
  final bangla = resource.titleBn?.trim();
  return SearchDocument<ContentResource>(
    item: resource,
    title: bangla?.isNotEmpty == true ? bangla! : resource.title,
    altTitle: bangla?.isNotEmpty == true ? resource.title : null,
    details: [
      resource.categoryNameBn,
      resource.categoryName,
      duaAzkarGroupForCategory(resource.categorySlug)?.titleBn,
      searchTypeLabel(resource.type),
      resource.summary,
      resource.referenceText,
      resource.sourceReference,
      resource.collectionName,
      resource.bookName,
      resource.surahNameBn,
      resource.surahName,
      resource.narrator,
    ],
  );
}

/// Display title of a resource (Bangla first).
String resourceDisplayTitle(ContentResource resource) {
  final bangla = resource.titleBn?.trim();
  return bangla?.isNotEmpty == true ? bangla! : resource.title;
}

/// Category label used for "বিভাগ" suggestions.
String? resourceCategoryLabel(ContentResource resource) {
  final bangla = resource.categoryNameBn?.trim();
  if (bangla?.isNotEmpty == true) return bangla;
  final english = resource.categoryName?.trim();
  return english?.isNotEmpty == true ? english : null;
}
