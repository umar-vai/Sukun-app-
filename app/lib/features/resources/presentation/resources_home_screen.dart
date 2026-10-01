import 'package:flutter/material.dart';

class ResourcesHomeScreen extends StatelessWidget {
  const ResourcesHomeScreen({super.key});

  static const categories = <(IconData, String)>[
    (Icons.auto_stories_outlined, "Qur'an"),
    (Icons.format_quote_outlined, 'Hadith'),
    (Icons.favorite_outline, 'Dua & Azkar'),
    (Icons.graphic_eq, 'Ruqyah'),
    (Icons.picture_as_pdf_outlined, 'Books & PDFs'),
    (Icons.article_outlined, 'Articles & Guides'),
    (Icons.headphones_outlined, 'Audio'),
    (Icons.ondemand_video_outlined, 'Video'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Islamic Resources')),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(category.$1, size: 32),
                  const SizedBox(height: 10),
                  Text(category.$2, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
