import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/presentation/linked_resource_buttons.dart';

void main() {
  testWidgets('shows approved resource sequence and its usage note', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkedResourceButtons(
            resources: const [
              LinkedResource(
                id: '719',
                title: 'Dua 719',
                type: 'dua',
                sortOrder: 0,
                usageNote: 'Open this resource first',
              ),
              LinkedResource(
                id: '718',
                title: 'Dua 718',
                type: 'dua',
                sortOrder: 1,
              ),
            ],
            onOpenResource: (resource) => opened.add(resource.id),
          ),
        ),
      ),
    );

    expect(find.text('Open this resource first'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Dua 719')).dx,
      lessThan(tester.getTopLeft(find.text('Dua 718')).dx),
    );
    await tester.tap(find.text('Dua 719'));
    expect(opened, ['719']);
  });
}
