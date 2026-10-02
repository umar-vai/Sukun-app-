class ContentCategory {
  const ContentCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.sortOrder,
    required this.isActive,
    this.parentId,
    this.nameBn,
  });

  factory ContentCategory.fromJson(Map<String, dynamic> json) =>
      ContentCategory(
        id: json['id'] as String,
        parentId: json['parent_id'] as String?,
        name: json['name'] as String,
        nameBn: json['name_bn'] as String?,
        slug: json['slug'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  final String id;
  final String? parentId;
  final String name;
  final String? nameBn;
  final String slug;
  final int sortOrder;
  final bool isActive;
}

class AdminContentItem {
  const AdminContentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.slug,
    required this.visibility,
    required this.status,
    required this.verificationStatus,
    this.categoryId,
    this.parentContentId,
    this.titleBn,
    this.summary,
    this.body,
    this.arabicText,
    this.banglaText,
    this.transliteration,
    this.translation,
    this.referenceText,
    this.sourceType,
    this.sourceReference,
    this.sourceUrl,
    this.sourceEdition,
    this.translationSource,
    this.surahNumber,
    this.surahName,
    this.surahNameBn,
    this.ayahNumber,
    this.ayahEndNumber,
    this.collectionName,
    this.bookName,
    this.hadithNumber,
    this.narrator,
    this.grade,
    this.author,
    this.publisher,
    this.chapterNumber,
    this.languageCode,
    this.rightsNote,
    this.thumbnailUrl,
    this.mediaSourceType,
    this.mediaUrl,
    this.youtubeVideoId,
    this.verifiedAt,
    this.publishedAt,
    this.archivedAt,
    this.updatedAt,
  });

  factory AdminContentItem.fromJson(Map<String, dynamic> json) =>
      AdminContentItem(
        id: json['id'] as String,
        type: json['type'] as String,
        categoryId: json['category_id'] as String?,
        parentContentId: json['parent_content_id'] as String?,
        title: json['title'] as String,
        titleBn: json['title_bn'] as String?,
        slug: json['slug'] as String,
        summary: json['summary'] as String?,
        body: json['body'] as String?,
        arabicText: json['arabic_text'] as String?,
        banglaText: json['bangla_text'] as String?,
        transliteration: json['transliteration'] as String?,
        translation: json['translation'] as String?,
        referenceText: json['reference_text'] as String?,
        sourceType: json['source_type'] as String?,
        sourceReference: json['source_reference'] as String?,
        sourceUrl: json['source_url'] as String?,
        sourceEdition: json['source_edition'] as String?,
        translationSource: json['translation_source'] as String?,
        verificationStatus: json['verification_status'] as String,
        surahNumber: json['surah_number'] as int?,
        surahName: json['surah_name'] as String?,
        surahNameBn: json['surah_name_bn'] as String?,
        ayahNumber: json['ayah_number'] as int?,
        ayahEndNumber: json['ayah_end_number'] as int?,
        collectionName: json['collection_name'] as String?,
        bookName: json['book_name'] as String?,
        hadithNumber: json['hadith_number'] as String?,
        narrator: json['narrator'] as String?,
        grade: json['grade'] as String?,
        author: json['author'] as String?,
        publisher: json['publisher'] as String?,
        chapterNumber: json['chapter_number'] as int?,
        languageCode: json['language_code'] as String?,
        rightsNote: json['rights_note'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        mediaSourceType: json['media_source_type'] as String?,
        mediaUrl: json['media_url'] as String?,
        youtubeVideoId: json['youtube_video_id'] as String?,
        visibility: json['visibility'] as String,
        status: json['status'] as String,
        verifiedAt: _date(json['verified_at']),
        publishedAt: _date(json['published_at']),
        archivedAt: _date(json['archived_at']),
        updatedAt: _date(json['updated_at']),
      );

  final String id;
  final String type;
  final String? categoryId;
  final String? parentContentId;
  final String title;
  final String? titleBn;
  final String slug;
  final String? summary;
  final String? body;
  final String? arabicText;
  final String? banglaText;
  final String? transliteration;
  final String? translation;
  final String? referenceText;
  final String? sourceType;
  final String? sourceReference;
  final String? sourceUrl;
  final String? sourceEdition;
  final String? translationSource;
  final String verificationStatus;
  final int? surahNumber;
  final String? surahName;
  final String? surahNameBn;
  final int? ayahNumber;
  final int? ayahEndNumber;
  final String? collectionName;
  final String? bookName;
  final String? hadithNumber;
  final String? narrator;
  final String? grade;
  final String? author;
  final String? publisher;
  final int? chapterNumber;
  final String? languageCode;
  final String? rightsNote;
  final String? thumbnailUrl;
  final String? mediaSourceType;
  final String? mediaUrl;
  final String? youtubeVideoId;
  final String visibility;
  final String status;
  final DateTime? verifiedAt;
  final DateTime? publishedAt;
  final DateTime? archivedAt;
  final DateTime? updatedAt;

  bool get isCanonical => type == 'quran' || type == 'hadith';
  bool get canEdit => status == 'draft' || status == 'review';
}

class ContentReview {
  const ContentReview({
    required this.id,
    required this.decision,
    required this.createdAt,
    this.notes,
  });

  factory ContentReview.fromJson(Map<String, dynamic> json) => ContentReview(
    id: json['id'] as int,
    decision: json['decision'] as String,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final int id;
  final String decision;
  final String? notes;
  final DateTime createdAt;
}

class AdminContentCollection {
  const AdminContentCollection({
    required this.id,
    required this.type,
    required this.title,
    required this.slug,
    required this.visibility,
    required this.status,
    this.titleBn,
    this.summary,
    this.contentItemIds = const [],
  });

  factory AdminContentCollection.fromJson(Map<String, dynamic> json) =>
      AdminContentCollection(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        titleBn: json['title_bn'] as String?,
        slug: json['slug'] as String,
        summary: json['summary'] as String?,
        visibility: json['visibility'] as String,
        status: json['status'] as String,
        contentItemIds:
            (json['content_collection_items'] as List<dynamic>? ?? const [])
                .map((row) => (row as Map<String, dynamic>)['content_item_id'])
                .whereType<String>()
                .toList(growable: false),
      );

  final String id;
  final String type;
  final String title;
  final String? titleBn;
  final String slug;
  final String? summary;
  final String visibility;
  final String status;
  final List<String> contentItemIds;
}

class SaveContentCollectionInput {
  const SaveContentCollectionInput({
    required this.type,
    required this.title,
    required this.slug,
    required this.visibility,
    required this.contentItemIds,
    required this.requestId,
    this.collectionId,
    this.titleBn,
    this.summary,
  });

  final String? collectionId;
  final String type;
  final String title;
  final String? titleBn;
  final String slug;
  final String? summary;
  final String visibility;
  final List<String> contentItemIds;
  final String requestId;

  String? validate() {
    if (type != 'selected_ayat' && type != 'ruqyah_ayat') {
      return 'Choose a supported Ayat collection type.';
    }
    if (title.trim().isEmpty) return 'Collection title is required.';
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
      return 'Slug must use lowercase words separated by hyphens.';
    }
    if (visibility != 'public' && visibility != 'patient_only') {
      return 'Collections can be public or patient-only.';
    }
    if (contentItemIds.isEmpty) return 'Select at least one verified Ayah.';
    if (contentItemIds.toSet().length != contentItemIds.length) {
      return 'The same Ayah cannot be selected twice.';
    }
    return null;
  }
}

class SaveContentInput {
  const SaveContentInput({
    required this.type,
    required this.title,
    required this.slug,
    required this.visibility,
    required this.status,
    required this.requestId,
    this.contentItemId,
    this.categoryId,
    this.parentContentId,
    this.titleBn,
    this.summary,
    this.body,
    this.arabicText,
    this.banglaText,
    this.transliteration,
    this.translation,
    this.referenceText,
    this.sourceType,
    this.sourceReference,
    this.sourceUrl,
    this.sourceEdition,
    this.translationSource,
    this.surahNumber,
    this.surahName,
    this.surahNameBn,
    this.ayahNumber,
    this.ayahEndNumber,
    this.collectionName,
    this.bookName,
    this.hadithNumber,
    this.narrator,
    this.grade,
    this.author,
    this.publisher,
    this.chapterNumber,
    this.languageCode,
    this.rightsNote,
    this.thumbnailUrl,
    this.mediaSourceType,
    this.mediaUrl,
    this.youtubeVideoId,
  });

  final String? contentItemId;
  final String type;
  final String? categoryId;
  final String? parentContentId;
  final String title;
  final String? titleBn;
  final String slug;
  final String? summary;
  final String? body;
  final String? arabicText;
  final String? banglaText;
  final String? transliteration;
  final String? translation;
  final String? referenceText;
  final String? sourceType;
  final String? sourceReference;
  final String? sourceUrl;
  final String? sourceEdition;
  final String? translationSource;
  final int? surahNumber;
  final String? surahName;
  final String? surahNameBn;
  final int? ayahNumber;
  final int? ayahEndNumber;
  final String? collectionName;
  final String? bookName;
  final String? hadithNumber;
  final String? narrator;
  final String? grade;
  final String? author;
  final String? publisher;
  final int? chapterNumber;
  final String? languageCode;
  final String? rightsNote;
  final String? thumbnailUrl;
  final String? mediaSourceType;
  final String? mediaUrl;
  final String? youtubeVideoId;
  final String visibility;
  final String status;
  final String requestId;

  bool get isCanonical => type == 'quran' || type == 'hadith';

  String? validate() {
    if (title.trim().isEmpty) return 'Title is required.';
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
      return 'Slug must use lowercase words separated by hyphens.';
    }
    if (status != 'draft' && status != 'review') {
      return 'Content can only be saved as draft or review.';
    }
    if (isCanonical && sourceType?.trim().toLowerCase() == 'generative_ai') {
      return "Canonical Qur'an and Hadith text cannot be AI-generated.";
    }
    if (type == 'quran' &&
        (surahNumber == null ||
            surahNumber! < 1 ||
            surahNumber! > 114 ||
            ayahNumber == null ||
            ayahNumber! < 1)) {
      return "Qur'an resources require valid Surah and Ayah numbers.";
    }
    if (ayahEndNumber != null &&
        (ayahNumber == null || ayahEndNumber! < ayahNumber!)) {
      return 'Ending Ayah cannot be before the starting Ayah.';
    }
    if (type == 'book_chapter' &&
        (parentContentId == null || chapterNumber == null)) {
      return 'Book chapters require a parent book and chapter number.';
    }
    if (sourceUrl != null &&
        sourceUrl!.trim().isNotEmpty &&
        !sourceUrl!.trim().startsWith('https://')) {
      return 'Source URL must use HTTPS.';
    }
    if (mediaSourceType == 'youtube' &&
        (youtubeVideoId == null || youtubeVideoId!.trim().isEmpty)) {
      return 'YouTube resources require a video ID.';
    }
    if (mediaSourceType != null &&
        mediaSourceType != 'youtube' &&
        (mediaUrl == null || !mediaUrl!.trim().startsWith('https://'))) {
      return 'External media requires an HTTPS URL.';
    }
    return null;
  }
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

const contentTypes = <String>[
  'dua',
  'amal',
  'quran',
  'hadith',
  'article',
  'guide',
  'audio',
  'video',
  'pdf',
  'book',
  'book_chapter',
  'external_link',
];

const resourceVisibilities = <String>[
  'public',
  'patient_only',
  'assigned_only',
  'staff_only',
];

const mediaSourceTypes = <String>[
  'direct_audio_url',
  'direct_video_url',
  'youtube',
  'external_pdf',
  'external_web',
];
