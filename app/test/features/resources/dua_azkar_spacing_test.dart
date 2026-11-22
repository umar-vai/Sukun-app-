import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/dua_azkar_browse_section.dart';

// Only groups holding a published dua are shown; give each one an item.
final _items = [
  for (final category in [
    'dua-azkar-morning',
    'dua-azkar-masnun',
    'dua-azkar-protection',
  ])
    ContentResource(
      id: category,
      type: 'dua',
      title: category,
      categorySlug: category,
      visibility: 'public',
      status: 'published',
    ),
];

void main() {
  testWidgets('Dua parent cards retain 16px gaps on a 420px phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: DuaAzkarBrowseSection(resources: _items),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = tester.getRect(
      find.byKey(const Key('dua-group-card-time-based')),
    );
    final second = tester.getRect(
      find.byKey(const Key('dua-group-card-everyday')),
    );
    final third = tester.getRect(
      find.byKey(const Key('dua-group-card-support')),
    );

    expect(first.left, 20);
    expect(second.left, 20);
    expect(third.left, 20);
    expect(second.top - first.bottom, closeTo(16, 0.1));
    expect(third.top - second.bottom, closeTo(16, 0.1));
    expect(tester.takeException(), isNull);
  });
}
