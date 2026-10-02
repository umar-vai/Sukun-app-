import 'package:flutter/material.dart';

class ResourceSection {
  const ResourceSection({
    required this.slug,
    required this.title,
    required this.titleBn,
    required this.icon,
    required this.types,
    this.categoryPrefixes = const {},
  });

  final String slug;
  final String title;
  final String titleBn;
  final IconData icon;
  final Set<String> types;
  final Set<String> categoryPrefixes;
}

const resourceSections = <ResourceSection>[
  ResourceSection(
    slug: 'quran',
    title: "Qur'an",
    titleBn: 'কুরআন',
    icon: Icons.auto_stories_outlined,
    types: {'quran'},
  ),
  ResourceSection(
    slug: 'hadith',
    title: 'Hadith',
    titleBn: 'হাদিস',
    icon: Icons.format_quote_outlined,
    types: {'hadith'},
  ),
  ResourceSection(
    slug: 'dua-azkar',
    title: 'Dua & Azkar',
    titleBn: 'দোয়া ও যিকর',
    icon: Icons.favorite_outline,
    types: {'dua', 'amal'},
    categoryPrefixes: {'dua', 'azkar'},
  ),
  ResourceSection(
    slug: 'ruqyah',
    title: 'Ruqyah',
    titleBn: 'রুকইয়াহ',
    icon: Icons.graphic_eq,
    types: {'amal', 'audio', 'guide'},
    categoryPrefixes: {'ruqyah'},
  ),
  ResourceSection(
    slug: 'books-pdfs',
    title: 'Books & PDFs',
    titleBn: 'বই ও পিডিএফ',
    icon: Icons.picture_as_pdf_outlined,
    types: {'book', 'book_chapter', 'pdf'},
  ),
  ResourceSection(
    slug: 'articles-guides',
    title: 'Articles & Guides',
    titleBn: 'আর্টিকেল ও গাইড',
    icon: Icons.article_outlined,
    types: {'article', 'guide'},
  ),
  ResourceSection(
    slug: 'audio',
    title: 'Audio',
    titleBn: 'অডিও',
    icon: Icons.headphones_outlined,
    types: {'audio'},
  ),
  ResourceSection(
    slug: 'video',
    title: 'Video',
    titleBn: 'ভিডিও',
    icon: Icons.ondemand_video_outlined,
    types: {'video'},
  ),
];

ResourceSection? resourceSectionBySlug(String? slug) {
  if (slug == null || slug.isEmpty) return null;
  return resourceSections.where((section) => section.slug == slug).firstOrNull;
}
