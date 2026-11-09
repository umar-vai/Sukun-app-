import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/self_ruqyah_guide_index.dart';

ContentResource _topic(String slug, String name) => ContentResource(
  id: slug,
  slug: slug,
  type: 'guide',
  title: name,
  titleBn: name,
  visibility: 'public',
  status: 'published',
);

void main() {
  testWidgets('groups the approved self-ruqyah topics into four chapters',
      (tester) async {
    String? selected;
    final resources = [
      _topic('srg2024-c01-t001', 'রুকইয়াহ'),
      _topic('srg2024-c02-t001', 'বদনজরের চিকিৎসা'),
      _topic('srg2024-c03-t001', 'মানসিক প্রস্তুতি'),
      _topic('srg2024-c04-t001', 'রুকইয়াহ পদ্ধতি'),
      _topic('unrelated-resource', 'এই লেখা গাইডের নয়'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SelfRuqyahGuideIndex(
            resources: resources,
            onOpenResource: (item) => selected = item.id,
          ),
        ),
      ),
    ));

    expect(find.text('প্রথম অধ্যায়'), findsOneWidget);
    expect(find.text('দ্বিতীয় অধ্যায়'), findsOneWidget);
    expect(find.text('তৃতীয় অধ্যায়'), findsOneWidget);
    expect(find.text('চতুর্থ অধ্যায়'), findsOneWidget);
    expect(find.text('এই লেখা গাইডের নয়'), findsNothing);
    expect(find.text('রুকইয়াহ'), findsOneWidget);

    await tester.tap(find.text('রুকইয়াহ'));
    expect(selected, 'srg2024-c01-t001');
  });

  testWidgets('search filters guide titles without modifying source text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SelfRuqyahGuideIndex(
            resources: [
              _topic('srg2024-c01-t001', 'রুকইয়াহ'),
              _topic('srg2024-c02-t001', 'জাদুর লক্ষণ'),
              _topic('srg2024-c03-t001', 'রুকইয়াহ গোসল'),
              _topic('srg2024-c04-t001', 'জাদুর আয়াত'),
            ],
            onOpenResource: (_) {},
          ),
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'জাদুর');
    await tester.pumpAndSettle();
    expect(find.text('প্রথম অধ্যায়'), findsNothing);
    expect(find.text('দ্বিতীয় অধ্যায়'), findsOneWidget);
    expect(find.text('চতুর্থ অধ্যায়'), findsOneWidget);
    expect(find.text('তৃতীয় অধ্যায়'), findsNothing);
  });
}
