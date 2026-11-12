import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/data/care_template_repository.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/presentation/care_templates_admin_screen.dart';

class _FakeRepository implements CareTemplateRepository {
  _FakeRepository(this.templates);

  List<OfficialPrescriptionTemplate> templates;
  final saved = <OfficialPrescriptionTemplate>[];

  @override
  Future<CareTemplateCatalog> load() async =>
      CareTemplateCatalog(templates: templates, editable: true);

  @override
  Future<OfficialPrescriptionTemplate> save(
    OfficialPrescriptionTemplate template,
  ) async {
    saved.add(template);
    return template;
  }
}

const _baqarah = OfficialPrescriptionTemplate(
  id: 'a07',
  category: 'amal',
  title: 'প্রতিদিন সূরা বাকারা শ্রবণ',
  instruction: 'প্রতিদিন সূরা বাকারা শুনবেন।',
  actionType: 'amal',
  defaultTimes: [ReminderClock(21, 0)],
  resourceRefs: ['sukun-ruqyahbd-baqara', 'quran:2'],
);

const _hiddenBath = OfficialPrescriptionTemplate(
  id: 'b09',
  category: 'bath',
  title: 'আরবি মাসের মাঝামাঝি গোসল',
  instruction: 'গোসল করবেন।',
  actionType: 'bath',
  defaultTimes: [ReminderClock(10, 0)],
  resourceRefs: [],
  isActive: false,
);

Future<_FakeRepository> _pump(WidgetTester tester) async {
  final repository = _FakeRepository([_baqarah, _hiddenBath]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [careTemplateRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: CareTemplatesAdminScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('lists active templates with their times and content count', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const Key('care-template-a07')), findsOneWidget);
    expect(find.text(_baqarah.title), findsOneWidget);
    expect(find.text(_hiddenBath.title), findsNothing);
    expect(find.byKey(const Key('care-templates-add')), findsOneWidget);
  });

  testWidgets('removing a template hides it after confirmation', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await tester.tap(find.byTooltip('সরান'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'সরান'));
    await tester.pumpAndSettle();

    expect(repository.saved.single.id, 'a07');
    expect(repository.saved.single.isActive, isFalse);
    // Content links are kept, so the template comes back unchanged.
    expect(repository.saved.single.resourceRefs, _baqarah.resourceRefs);
    expect(find.text(_baqarah.title), findsNothing);
  });

  testWidgets('removed templates can be shown and restored', (tester) async {
    final repository = await _pump(tester);
    await tester.tap(find.text('সরানো'));
    await tester.pumpAndSettle();
    expect(find.text(_hiddenBath.title), findsOneWidget);
    await tester.tap(find.byTooltip('ফিরিয়ে আনুন'));
    await tester.pumpAndSettle();
    expect(repository.saved.single.isActive, isTrue);
  });
}
