import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';

void main() {
  testWidgets('audio and editorial resource cards remain concise', (
    tester,
  ) async {
    const audio = ContentResource(
      id: 'audio-test',
      title: 'রুকইয়াহ শুনুন',
      type: 'audio',
      summary: 'Owner-provided source; editorial review required before publishing.',
      status: 'published',
      visibility: 'public',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResourceCard(resource: audio, onTap: () {}),
        ),
      ),
    );
    expect(find.text('রুকইয়াহ শুনুন'), findsOneWidget);
    expect(find.textContaining('editorial review required'), findsNothing);
  });
}
