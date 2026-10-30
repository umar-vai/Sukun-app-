import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

void main() {
  testWidgets('dark search uses navy surface and readable text, not white', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final darkTheme = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: SukunColors.sukunBlue,
        surfaceContainerLow: Color(0xFF243848),
        onSurface: Color(0xFFF2F7FA),
        outline: Color(0xFF536674),
      ),
    );
    String? entered;
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: SukunSearchField(
            controller: controller,
            hintText: 'নাম বা বিষয় লিখে খুঁজুন',
            onChanged: (value) => entered = value,
          ),
        ),
      ),
    );
    final surface = tester.widget<Container>(
      find.byKey(const Key('sukun-search-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color, darkTheme.colorScheme.surfaceContainerLow);
    expect(decoration.color, isNot(Colors.white));
    expect(decoration.boxShadow, isEmpty);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.color, darkTheme.colorScheme.onSurface);
    expect(field.decoration!.hintStyle!.color, isNot(Colors.white10));
    final searchIcon = field.decoration!.prefixIcon! as Icon;
    expect(searchIcon.color, isNot(Colors.white10));

    await tester.enterText(find.byType(TextField), 'রুকইয়াহ');
    expect(controller.text, 'রুকইয়াহ');
    expect(entered, 'রুকইয়াহ');
  });

  testWidgets('light search retains original white surface', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SukunSearchField(
            controller: controller,
            hintText: 'নাম বা বিষয় লিখে খুঁজুন',
          ),
        ),
      ),
    );

    final surface = tester.widget<Container>(
      find.byKey(const Key('sukun-search-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect((decoration.border! as Border).top.color, SukunColors.border);
    expect(decoration.boxShadow, isNotEmpty);
  });
}
