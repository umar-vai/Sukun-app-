import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/presentation/dua_azkar_browse_section.dart';

void main() {
  testWidgets('Dua parent cards retain 16px gaps on a 420px phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: DuaAzkarBrowseSection(resources: []),
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
