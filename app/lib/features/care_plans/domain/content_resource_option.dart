class ContentResourceOption {
  const ContentResourceOption({
    required this.id,
    required this.title,
    required this.type,
    required this.visibility,
    required this.status,
    this.titleBn,
    this.categoryId,
    this.categoryName,
    this.categoryNameBn,
    this.categorySlug,
    this.categorySortOrder = 999,
  });

  factory ContentResourceOption.fromJson(Map<String, dynamic> json) {
    final category = json['content_categories'];
    final categoryMap = category is Map<String, dynamic>
        ? category
        : category is Map
        ? Map<String, dynamic>.from(category)
        : null;
    return ContentResourceOption(
      id: json['id'] as String,
      title: json['title'] as String,
      titleBn: json['title_bn'] as String?,
      type: json['type'] as String,
      visibility: json['visibility'] as String,
      status: json['status'] as String? ?? 'draft',
      categoryId: json['category_id'] as String?,
      categoryName: categoryMap?['name'] as String?,
      categoryNameBn: categoryMap?['name_bn'] as String?,
      categorySlug: categoryMap?['slug'] as String?,
      categorySortOrder: categoryMap?['sort_order'] as int? ?? 999,
    );
  }

  final String id;
  final String title;
  final String? titleBn;
  final String type;
  final String visibility;
  final String status;
  final String? categoryId;
  final String? categoryName;
  final String? categoryNameBn;
  final String? categorySlug;
  final int categorySortOrder;

  bool get isPatientAccessible =>
      visibility == 'public' ||
      visibility == 'patient_only' ||
      visibility == 'assigned_only';

  bool get isLinkable => status == 'published' && isPatientAccessible;

  String get displayTitle {
    final bangla = titleBn?.trim();
    return bangla?.isNotEmpty == true ? bangla! : title;
  }

  String get categoryLabel {
    final bangla = categoryNameBn?.trim();
    if (bangla?.isNotEmpty == true) return bangla!;
    final english = categoryName?.trim();
    return english?.isNotEmpty == true ? english! : 'Uncategorized';
  }

  String get linkabilityMessage {
    if (status != 'published') {
      return 'Not linkable until this resource is published.';
    }
    if (!isPatientAccessible) {
      return 'Staff-only resources cannot be linked to a patient action.';
    }
    return 'Available to link';
  }
}
