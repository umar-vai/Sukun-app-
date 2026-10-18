class ContentResourceOption {
  const ContentResourceOption({
    required this.id,
    required this.title,
    this.slug,
    required this.type,
    required this.visibility,
    required this.status,
    this.titleBn,
    this.surahNumber,
    this.ayahNumber,
    this.ayahEndNumber,
    this.verificationStatus,
    this.mediaSourceType,
    this.mediaUrl,
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
      slug: json['slug'] as String?,
      titleBn: json['title_bn'] as String?,
      surahNumber: json['surah_number'] as int?,
      ayahNumber: json['ayah_number'] as int?,
      ayahEndNumber: json['ayah_end_number'] as int?,
      verificationStatus: json['verification_status'] as String?,
      mediaSourceType: json['media_source_type'] as String?,
      mediaUrl: json['media_url'] as String?,
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
  final String? slug;
  final String? titleBn;
  final int? surahNumber;
  final int? ayahNumber;
  final int? ayahEndNumber;
  final String? verificationStatus;
  final String? mediaSourceType;
  final String? mediaUrl;
  final String type;
  final String visibility;
  final String status;
  final String? categoryId;
  final String? categoryName;
  final String? categoryNameBn;
  final String? categorySlug;
  final int categorySortOrder;

  /// A public Quran API chapter has a stable route, not a CMS UUID.
  int? get canonicalSurahNumber =>
      id.startsWith('quran:') ? int.tryParse(id.substring(6)) : null;

  bool get isPatientAccessible =>
      visibility == 'public' ||
      visibility == 'patient_only' ||
      visibility == 'assigned_only';

  bool get isLinkable =>
      (canonicalSurahNumber != null || status == 'published') &&
      isPatientAccessible &&
      (type != 'quran' ||
          canonicalSurahNumber != null ||
          verificationStatus == 'verified');

  String get displayTitle {
    final bangla = titleBn?.trim();
    return bangla?.isNotEmpty == true ? bangla! : title;
  }

  bool get isEditorialRuqyahExcerpt =>
      type == 'article' && (slug?.startsWith('srg2024-qur-') ?? false);

  String get categoryLabel {
    if (canonicalSurahNumber != null) return '১১৪ সূরার কুরআন';
    if (isEditorialRuqyahExcerpt) {
      return 'রুকইয়াহ আয়াত · সম্পাদিত উদ্ধৃতি';
    }
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
