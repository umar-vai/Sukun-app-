import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/data/care_template_repository.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/presentation/bulk_template_import_screen.dart';

const _water = ContentResourceOption(
  id: 'id-water',
  slug: 'srg2024-sup-001',
  title: 'Water',
  titleBn: 'পানি',
  type: 'article',
  visibility: 'public',
  status: 'published',
);

Map<String, dynamic> _row({
  String id = 's01',
  String title = 'ডাটাবেসের পানি',
  bool active = true,
}) => {
  'id': id,
  'category': 'supplement',
  'title': title,
  'instruction': 'দিনে {বার} বার পান করবেন।',
  'action_type': 'supplement',
  'default_times': ['07:15:00', '19:45:00'],
  'resource_refs': ['srg2024-sup-001', 'quran:1'],
  'requires_resource': true,
  'is_active': active,
  'sort_order': 120,
};

void main() {
  group('template from the database', () {
    test('reads times, links and flags, and saves them back', () {
      final template = OfficialPrescriptionTemplate.fromJson(_row());
      expect(defaultTimesForTemplate(template), const [
        ReminderClock(7, 15),
        ReminderClock(19, 45),
      ]);
      expect(template.requiresLinkedResource, isTrue);
      expect(template.requiredVariables, ['বার']);
      expect(
        suggestResourcesForTemplate(template, const [_water]).map((r) => r.id),
        ['id-water'],
      );
      final json = template.toSaveJson();
      expect(json['id'], 's01');
      expect(json['default_times'], ['07:15:00', '19:45:00']);
      expect(json['resource_refs'], ['srg2024-sup-001', 'quran:1']);
      expect(json['sort_order'], 120);
    });

    test('database links replace the built-in ones', () {
      final template = OfficialPrescriptionTemplate.fromJson({
        ..._row(),
        'resource_refs': <String>[],
        'default_times': <String>[],
      });
      // An admin who removed every link gets none back from code.
      expect(suggestResourcesForTemplate(template, const [_water]), isEmpty);
      // No saved time falls back to the category default, never nothing.
      expect(defaultTimesForTemplate(template), isNotEmpty);
    });

    test('search treats composed and two-part Bangla letters alike', () {
      expect(
        foldBanglaForSearch('\u09B0\u09C1\u0995\u0987\u09DF\u09BE\u09B9'),
        foldBanglaForSearch('\u09B0\u09C1\u0995\u0987\u09AF\u09BC\u09BE\u09B9'),
      );
    });

    test('a template reminder name is read, saved and used on import', () {
      final named = OfficialPrescriptionTemplate.fromJson({
        ..._row(),
        'notification_title': '  পানি পানের সময়  ',
      });
      expect(named.notificationTitle, 'পানি পানের সময়');
      expect(named.toSaveJson()['notification_title'], 'পানি পানের সময়');
      final item = BulkImportItem.template(named);
      expect(item.defaultNotificationTitle, 'পানি পানের সময়');
      expect(item.effectiveNotificationTitle, 'পানি পানের সময়');
      item.notificationTitle = 'শুধু এই রোগীর জন্য';
      expect(item.effectiveNotificationTitle, 'শুধু এই রোগীর জন্য');

      final unnamed = OfficialPrescriptionTemplate.fromJson({
        ..._row(),
        'notification_title': '   ',
      });
      expect(unnamed.notificationTitle, isNull);
      expect(unnamed.toSaveJson()['notification_title'], isNull);
      expect(
        BulkImportItem.template(unnamed).effectiveNotificationTitle,
        'ডাটাবেসের পানি',
      );
    });

    test('a new template sends no id so the server picks one', () {
      const draft = OfficialPrescriptionTemplate(
        id: '',
        category: 'special',
        title: 'নতুন',
        instruction: 'করবেন।',
        actionType: 'amal',
      );
      expect(draft.toSaveJson().containsKey('id'), isFalse);
      expect(actionTypeForTemplateCategory('special'), 'amal');
      expect(actionTypeForTemplateCategory('bath'), 'bath');
    });
  });

  testWidgets('picker shows live templates and saves an edit in place', (
    tester,
  ) async {
    final saved = <OfficialPrescriptionTemplate>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showBulkTemplateImport(
                context,
                recipientLabel: 'রোগী: Test',
                resources: Future.value(const [_water]),
                templates: Future.value(
                  CareTemplateCatalog(
                    templates: [
                      OfficialPrescriptionTemplate.fromJson(_row()),
                      OfficialPrescriptionTemplate.fromJson(
                        _row(id: 's02', title: 'লুকানো', active: false),
                      ),
                    ],
                    editable: true,
                  ),
                ),
                saveTemplate: (draft) async {
                  saved.add(draft);
                  return draft;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('ডাটাবেসের পানি'), findsOneWidget);
    expect(find.text('লুকানো'), findsNothing);
    expect(find.text('সুকুন টেমপ্লেট (১)'), findsOneWidget);
    expect(find.byKey(const Key('bulk-template-new')), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('টেমপ্লেট এডিট'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('টেমপ্লেট এডিট'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('care-template-title')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('care-template-title')),
      'নতুন শিরোনাম',
    );
    final nameBox = find.byKey(const Key('care-template-notification-title'));
    await tester.scrollUntilVisible(
      nameBox,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(nameBox, 'পানি পানের সময় হয়েছে');
    await tester.tap(find.byKey(const Key('care-template-save')));
    await tester.pumpAndSettle();

    expect(saved.single.id, 's01');
    expect(saved.single.title, 'নতুন শিরোনাম');
    expect(saved.single.notificationTitle, 'পানি পানের সময় হয়েছে');
    expect(saved.single.resourceRefs, ['srg2024-sup-001', 'quran:1']);
    expect(find.text('নতুন শিরোনাম'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('built-in templates cannot be edited', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BulkTemplateImportScreen(
          recipientLabel: 'রোগী: Test',
          resources: Future.value(const <ContentResourceOption>[]),
          saveTemplate: (draft) async => draft,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('টেমপ্লেট এডিট'), findsNothing);
    expect(find.byKey(const Key('bulk-template-new')), findsNothing);
  });
}
