import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
  test('every book topic is assigned to exactly one chapter subgroup', () {
    const totals = [15, 28, 37, 37];
    expect(selfRuqyahChapterTitles, hasLength(4));
    for (var chapter = 1; chapter <= 4; chapter++) {
      for (var topic = 1; topic <= totals[chapter - 1]; topic++) {
        final slug =
            'srg2024-c0$chapter-t${topic.toString().padLeft(3, '0')}';
        final number = selfRuqyahTopicNumber(slug, chapter);
        expect(number, topic);
        final matches = selfRuqyahGroups.where(
          (group) =>
              group.chapter == chapter &&
              topic >= group.firstTopic &&
              topic <= group.lastTopic,
        );
        expect(matches, hasLength(1), reason: 'Unassigned topic $slug');
      }
    }
    expect(selfRuqyahTopicNumber('other-slug', 4), isNull);
    expect(selfRuqyahTopicNumber('srg2024-c01-t001', 3), isNull);
    expect(selfRuqyahGroupBySlug(4, 'fake-group'), isNull);
  });

  testWidgets('entry point shows four chapter cards, not 117 flat topics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SelfRuqyahGuideIndex(
              resources: [
                _topic('srg2024-c01-t001', 'রুকইয়াহ'),
                _topic('srg2024-c02-t001', 'বদনজর'),
                _topic('srg2024-c03-t001', 'প্রস্তুতি'),
                _topic('srg2024-c04-t001', 'রুকইয়াহ পদ্ধতি'),
                _topic('unrelated', 'অন্য কনটেন্ট'),
              ],
              onOpenResource: (_) {},
            ),
          ),
        ),
      ),
    );
    for (var chapter = 1; chapter <= 4; chapter++) {
      expect(find.byKey(Key('self-guide-chapter-$chapter')), findsOneWidget);
    }
    expect(find.byKey(const Key('self-guide-topic-srg2024-c01-t001')),
        findsNothing);
    expect(find.text('অন্য কনটেন্ট'), findsNothing);
  });

  testWidgets('chapter to subgroup to article preserves exact resource ID', (
    tester,
  ) async {
    final resources = [
      _topic('srg2024-c01-t001', 'রুকইয়াহ'),
      _topic('srg2024-c02-t001', 'বদনজর ও প্রাথমিক আলোচনা'),
      _topic('srg2024-c02-t006', 'জাদু ও প্রাথমিক আলোচনা'),
      _topic('unrelated', 'অন্য কনটেন্ট'),
    ];
    String? selected;
    Widget screen(int? chapter, String? group) => Scaffold(
      body: SingleChildScrollView(
        child: SelfRuqyahGuideIndex(
          resources: resources,
          chapterNumber: chapter,
          groupSlug: group,
          onOpenResource: (resource) => selected = resource.id,
        ),
      ),
    );
    final router = GoRouter(
      initialLocation: '/resources/ruqyah/ruqyah-self-guide',
      routes: [
        GoRoute(
          path: '/resources/ruqyah/ruqyah-self-guide',
          builder: (_, _) => screen(null, null),
          routes: [
            GoRoute(
              path: 'chapter/:chapter',
              builder: (_, state) => screen(
                int.tryParse(state.pathParameters['chapter'] ?? ''),
                null,
              ),
              routes: [
                GoRoute(
                  path: 'group/:group',
                  builder: (_, state) => screen(
                    int.tryParse(state.pathParameters['chapter'] ?? ''),
                    state.pathParameters['group'],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('self-guide-chapter-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('self-guide-group-evil-eye')),
        findsOneWidget);
    expect(find.text('বদনজর ও প্রাথমিক আলোচনা'), findsNothing);

    await tester.tap(find.byKey(const Key('self-guide-group-evil-eye')));
    await tester.pumpAndSettle();
    expect(find.text('বদনজর ও প্রাথমিক আলোচনা'), findsOneWidget);
    expect(find.text('জাদু ও প্রাথমিক আলোচনা'), findsNothing);

    await tester.tap(find.text('বদনজর ও প্রাথমিক আলোচনা'));
    expect(selected, 'srg2024-c02-t001');
  });
}
