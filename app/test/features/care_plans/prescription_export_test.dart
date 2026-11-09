import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/data/prescription_overview.dart';
import 'package:sukun_life/features/care_plans/data/prescription_pdf.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/domain/prescription_summary.dart';
import 'package:sukun_life/features/care_plans/presentation/prescription_overview_card.dart';

PlanAction _action(
  String title, {
  String type = 'amal',
  String? instruction,
  ActionReviewStatus status = ActionReviewStatus.approved,
}) => PlanAction(
  id: title,
  carePlanId: 'live',
  type: type,
  title: title,
  instruction: instruction,
  frequency: const ActionFrequency.daily(),
  startDate: DateTime(2026, 11),
  sortOrder: 0,
  reviewStatus: status,
  reminderEnabled: true,
);

void main() {
  test('sections follow template categories and repeats print once', () {
    final sections = groupPrescription([
      entryFromPlanAction(_action('সকাল–সন্ধ্যার মাসনুন আমল (সকাল)')),
      entryFromPlanAction(_action('সকাল–সন্ধ্যার মাসনুন আমল (সন্ধ্যা)')),
      entryFromPlanAction(_action('সকালের পানিতে মধু', type: 'supplement')),
      entryFromPlanAction(_action('ঘুমের পূর্বের আমল')),
      entryFromPlanAction(_action('Ya-Sin', type: 'quran')),
    ]);
    expect(sections.map((s) => s.title), [
      'আমল',
      'সাপ্লিমেন্ট',
      'অডিও ও তিলাওয়াত',
    ]);
    expect(sections.first.entries.map((e) => e.title), [
      'সকাল–সন্ধ্যার মাসনুন আমল',
      'ঘুমের পূর্বের আমল',
    ]);
  });

  test('a section reads as one paragraph, not one item per line', () {
    final section = groupPrescription([
      const PrescriptionEntry(
        title: 'দরূদ শরীফ',
        instruction: 'দৈনিক দরূদ শরীফ ১০০ বার পড়বেন।',
        sectionId: 'amal',
      ),
      const PrescriptionEntry(title: 'ইস্তিগফার', sectionId: 'amal'),
    ]).single;
    final text = sectionParagraph(section);
    expect(text, isNot(contains('\n')));
    expect(text, 'দরূদ শরীফ: দৈনিক দরূদ শরীফ ১০০ বার পড়বেন।  ইস্তিগফার।');
  });

  test('overview splits admin-set from self-added, skips unapproved', () async {
    final overview = await loadPrescriptionOverview(
      carePlans: _Plans([
        _action('ঘুমের পূর্বের আমল'),
        _action('AI draft', status: ActionReviewStatus.needsReview),
      ]),
      plans: [
        CarePlan(
          id: 'live',
          patientId: 'p1',
          version: 1,
          name: 'Plan',
          startDate: DateTime(2026, 11),
          status: CarePlanStatus.active,
          createdAt: DateTime(2026, 11),
        ),
      ],
      userId: 'u1',
      routines: (_) async => [
        {
          'is_active': true,
          'assigned_by_admin': true,
          'actions': [
            {'title': 'রুকইয়াহ পানি দুই বেলা (সকাল)', 'is_active': true},
          ],
        },
        {
          'is_active': true,
          'assigned_by_admin': false,
          'actions': [
            {
              'title': 'Surah Mulk',
              'resource_type': 'quran',
              'is_active': true,
            },
          ],
        },
        {
          'is_active': false,
          'assigned_by_admin': false,
          'actions': [
            {'title': 'Paused', 'is_active': true},
          ],
        },
      ],
    );
    expect(
      overview.adminSections.expand((s) => s.entries).map((e) => e.title),
      ['ঘুমের পূর্বের আমল', 'রুকইয়াহ পানি দুই বেলা'],
    );
    expect(overview.selfSections.single.entries.single.title, 'Surah Mulk');
  });

  test('pdf builder makes A4 pages and a PDF file', () async {
    final sections = [
      PrescriptionSection(
        id: 'amal',
        title: 'আমল',
        entries: [
          for (var i = 0; i < 80; i++)
            PrescriptionEntry(
              title: 'Amal $i',
              instruction: 'Read the approved instruction carefully each day.',
              sectionId: 'amal',
            ),
        ],
      ),
    ];
    const builder = PrescriptionPdfBuilder(pixelRatio: 0.5);
    final pages = await builder.renderPages(
      recipientName: 'Test',
      sections: sections,
    );
    expect(pages.length, greaterThan(1));
    final pdf = await builder.build(recipientName: 'Test', sections: sections);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });

  testWidgets('self section appears only when the person added something', (
    tester,
  ) async {
    Future<void> pump(PrescriptionOverview overview) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrescriptionOverviewCard(
                key: UniqueKey(),
                recipientName: 'Test',
                overview: Future.value(overview),
                selfLabel: 'রোগী নিজে যোগ করেছেন',
                onDownload: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final admin = groupPrescription([
      const PrescriptionEntry(title: 'দরূদ শরীফ', sectionId: 'amal'),
    ]);
    await pump(PrescriptionOverview(adminSections: admin, selfSections: []));
    expect(find.byKey(const Key('prescription-admin-section')), findsOneWidget);
    expect(find.byKey(const Key('prescription-pdf-download')), findsOneWidget);
    expect(find.byKey(const Key('prescription-self-section')), findsNothing);

    await pump(PrescriptionOverview(adminSections: admin, selfSections: admin));
    expect(find.byKey(const Key('prescription-self-section')), findsOneWidget);
    expect(find.text('রোগী নিজে যোগ করেছেন'), findsOneWidget);
  });
}

final class _Plans implements CarePlansRepository {
  _Plans(this.actions);
  final List<PlanAction> actions;

  @override
  Future<List<PlanAction>> getActions(String planId) async => actions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
