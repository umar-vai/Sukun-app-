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
    slug: 'books-articles',
    title: 'Books & Articles',
    titleBn: 'বই ও আর্টিকেল',
    icon: Icons.library_books_outlined,
    types: {'book', 'book_chapter', 'pdf', 'article', 'guide'},
  ),
  ResourceSection(
    slug: 'blog',
    title: 'Blog',
    titleBn: 'ব্লগ',
    icon: Icons.edit_note_outlined,
    types: {'article'},
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
  if (slug == 'books-pdfs' || slug == 'articles-guides') {
    return resourceSectionBySlug('books-articles');
  }
  return resourceSections.where((section) => section.slug == slug).firstOrNull;
}
