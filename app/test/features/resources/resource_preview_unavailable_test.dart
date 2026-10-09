import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';
import 'package:sukun_life/features/resources/presentation/resource_category_screen.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';

void main() {
  const unavailable = UnavailableResourcesRepository();

  testWidgets('audio category explains missing preview backend without retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [resourcesRepositoryProvider.overrideWithValue(unavailable)],
        child: MaterialApp(
          home: ResourceCategoryScreen(
            section: resourceSectionBySlug('audio')!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('অডিও এখনো উপলব্ধ নয়'), findsOneWidget);
    expect(find.textContaining('রিসোর্স সার্ভার সংযুক্ত নেই'), findsOneWidget);
    expect(find.text('আবার চেষ্টা করুন'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('guest resource hub explains missing backend', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [resourcesRepositoryProvider.overrideWithValue(unavailable)],
        child: const MaterialApp(home: ResourcesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('রিসোর্স সার্ভার সংযুক্ত নেই'), findsOneWidget);
    expect(find.text('বিষয় অনুযায়ী দেখুন'), findsOneWidget);
    expect(find.text('অডিও'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
  });
}
