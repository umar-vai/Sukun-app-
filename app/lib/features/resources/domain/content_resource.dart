import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

class ContentResource {
  const ContentResource({
    required this.id,
    required this.type,
    required this.title,
    required this.visibility,
    required this.status,
    this.titleBn,
    this.summary,
    this.body,
    this.arabicText,
    this.banglaText,
    this.transliteration,
    this.translation,
    this.referenceText,
    this.sourceReference,
    this.mediaSourceType,
    this.mediaUrl,
    this.youtubeVideoId,
    this.thumbnailUrl,
    this.verificationStatus,
    this.createdAt,
    this.categoryId,
    this.categorySlug,
    this.categoryName,
    this.categoryNameBn,
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
  });

  factory ContentResource.fromJson(Map<String, dynamic> json) {
    final category = json['content_categories'] as Map<String, dynamic>?;
    return ContentResource(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      titleBn: json['title_bn'] as String?,
      summary: json['summary'] as String?,
      body: json['body'] as String?,
      arabicText: json['arabic_text'] as String?,
      banglaText: json['bangla_text'] as String?,
      transliteration: json['transliteration'] as String?,
      translation: json['translation'] as String?,
      referenceText: json['reference_text'] as String?,
      sourceReference: json['source_reference'] as String?,
      mediaSourceType: json['media_source_type'] as String?,
      mediaUrl: json['media_url'] as String?,
      youtubeVideoId: json['youtube_video_id'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      verificationStatus: json['verification_status'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      categoryId: json['category_id'] as String?,
      categorySlug: category?['slug'] as String?,
      categoryName: category?['name'] as String?,
      categoryNameBn: category?['name_bn'] as String?,
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
      visibility: json['visibility'] as String,
      status: json['status'] as String,
    );
  }

  final String id;
  final String type;
  final String title;
  final String? titleBn;
  final String? summary;
  final String? body;
  final String? arabicText;
  final String? banglaText;
  final String? transliteration;
  final String? translation;
  final String? referenceText;
  final String? sourceReference;
  final String? mediaSourceType;
  final String? mediaUrl;
  final String? youtubeVideoId;
  final String? thumbnailUrl;
  final String? verificationStatus;
  final DateTime? createdAt;
  final String? categoryId;
  final String? categorySlug;
  final String? categoryName;
  final String? categoryNameBn;
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
  final String visibility;
  final String status;

  LinkedResource get linkedResource => LinkedResource(
    id: id,
    title: title,
    titleBn: titleBn,
    type: type,
    mediaSourceType: mediaSourceType,
    mediaUrl: mediaUrl,
    youtubeVideoId: youtubeVideoId,
  );
}
