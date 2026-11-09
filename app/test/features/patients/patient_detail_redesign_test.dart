import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/data/patients_repository.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:sukun_life/features/patients/presentation/patient_detail_screen.dart';
import 'package:sukun_life/features/patients/presentation/patients_list_screen.dart';
import 'package:sukun_life/features/progress/data/progress_providers.dart';
import 'package:sukun_life/features/progress/data/progress_repository.dart';
import 'package:sukun_life/features/progress/domain/adherence_summary.dart';

const _patientId = 'p-1';

/// The redesign moved patient detail into tabs and a bottom action bar.
/// These tests prove every earlier capability is still reachable.
void main() {
  Future<GoRouter> pumpDetail(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/admin/patients/$_patientId',
      routes: [
        GoRoute(
          path: '/admin/patients/:id',
          builder: (_, state) =>
              PatientDetailScreen(patientId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'prescriptions/new',
              builder: (_, _) =>
                  const Scaffold(body: Text('New prescription page')),
            ),
            GoRoute(
              path: 'plans/new',
              builder: (_, state) => Scaffold(
                body: Text(
                  'New plan page ${state.uri.queryParameters['prescriptionId'] ?? '-'}',
                ),
              ),
            ),
            GoRoute(
              path: 'plans/:planId',
              builder: (_, state) => Scaffold(
                body: Text('Plan page ${state.pathParameters['planId']}'),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientsRepositoryProvider.overrideWithValue(_FakePatients()),
          carePlansRepositoryProvider.overrideWithValue(_FakePlans()),
          progressRepositoryProvider.overrideWithValue(_FakeProgress()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('header, progress and active plan show on the summary tab', (
    tester,
  ) async {
    await pumpDetail(tester);
    expect(find.text('Amina Rahman'), findsOneWidget);
    expect(find.text('SL-TEST-01'), findsOneWidget);
    expect(find.text('অবস্থা: চালু'), findsOneWidget);
    expect(find.byKey(const Key('patient-detail-progress')), findsOneWidget);
    expect(find.textContaining('টি সম্পন্ন'), findsOneWidget);
    expect(find.text('Active plan'), findsOneWidget);
    // Drafts live on the plans tab, not the summary.
    expect(find.text('Draft plan'), findsNothing);
    expect(find.text('Latest instruction'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plans tab lists every version and opens a plan', (tester) async {
    await pumpDetail(tester);
    await tester.tap(find.byKey(const Key('patient-detail-tab-plans')));
    await tester.pumpAndSettle();
    expect(find.text('Active plan'), findsOneWidget);
    expect(find.text('Draft plan'), findsOneWidget);
    await tester.tap(find.text('Draft plan'));
    await tester.pumpAndSettle();
    expect(find.text('Plan page plan-draft'), findsOneWidget);
  });

  testWidgets('prescriptions tab keeps staff-only marking and plan builder', (
    tester,
  ) async {
    await pumpDetail(tester);
    await tester.tap(find.byKey(const Key('patient-detail-tab-prescriptions')));
    await tester.pumpAndSettle();
    expect(find.text('Latest instruction'), findsOneWidget);
    expect(find.text('Older instruction'), findsOneWidget);
    expect(find.text('শুধু স্টাফ'), findsOneWidget);
    await tester.ensureVisible(find.text('সেবা পরিকল্পনা সাজান').last);
    await tester.tap(find.text('সেবা পরিকল্পনা সাজান').last);
    await tester.pumpAndSettle();
    expect(find.text('New plan page rx-old'), findsOneWidget);
  });

  testWidgets('bottom actions add a prescription or a plan directly', (
    tester,
  ) async {
    await pumpDetail(tester);
    await tester.tap(find.byKey(const Key('patient-detail-add-prescription')));
    await tester.pumpAndSettle();
    expect(find.text('New prescription page'), findsOneWidget);
  });

  testWidgets('bottom main action opens the bulk template picker', (
    tester,
  ) async {
    await pumpDetail(tester);
    await tester.tap(find.byKey(const Key('patient-detail-bulk-import')));
    await tester.pumpAndSettle();
    expect(find.text('আমল ও রিমাইন্ডার বাছুন'), findsOneWidget);
    expect(find.text('রোগী: Amina Rahman'), findsOneWidget);
    expect(find.byKey(const Key('bulk-template-a01')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('patient list shows the real status and filters by it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientsRepositoryProvider.overrideWithValue(_FakePatients()),
        ],
        child: const MaterialApp(home: PatientsListScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Amina Rahman'), findsOneWidget);
    expect(find.text('Karim Uddin'), findsOneWidget);
    await tester.tap(find.byKey(const Key('patients-filter-inactive')));
    await tester.pumpAndSettle();
    expect(find.text('Amina Rahman'), findsNothing);
    expect(find.text('Karim Uddin'), findsOneWidget);
    expect(find.text('নিষ্ক্রিয়'), findsOneWidget);
    await tester.tap(find.byKey(const Key('patients-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('Amina Rahman'), findsOneWidget);
  });
}

final _amina = Patient(
  id: _patientId,
  userId: 'u-1',
  patientCode: 'SL-TEST-01',
  fullName: 'Amina Rahman',
  phone: '+8801712345678',
  status: PatientStatus.active,
  createdAt: DateTime.utc(2026, 10),
);

final _karim = Patient(
  id: 'p-2',
  userId: 'u-2',
  patientCode: 'SL-TEST-02',
  fullName: 'Karim Uddin',
  status: PatientStatus.inactive,
  createdAt: DateTime.utc(2026, 10),
);

final class _FakePatients implements PatientsRepository {
  @override
  Future<Patient?> getPatient(String patientId) async => _amina;

  @override
  Future<List<Prescription>> getPrescriptions(String patientId) async => [
    Prescription(
      id: 'rx-new',
      patientId: _patientId,
      rawText: 'Latest instruction',
      visibility: PrescriptionVisibility.patient,
      createdAt: DateTime.utc(2026, 11, 2),
    ),
    Prescription(
      id: 'rx-old',
      patientId: _patientId,
      rawText: 'Older instruction',
      visibility: PrescriptionVisibility.staffOnly,
      createdAt: DateTime.utc(2026, 10, 2),
    ),
  ];

  @override
  Future<List<Patient>> searchPatients({String query = ''}) async => [
    _amina,
    _karim,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakePlans implements CarePlansRepository {
  @override
  Future<List<CarePlan>> getPatientPlans(String patientId) async => [
    CarePlan(
      id: 'plan-active',
      patientId: _patientId,
      version: 2,
      name: 'Active plan',
      startDate: DateTime.utc(2026, 11),
      status: CarePlanStatus.active,
      createdAt: DateTime.utc(2026, 11),
    ),
    CarePlan(
      id: 'plan-draft',
      patientId: _patientId,
      version: 3,
      name: 'Draft plan',
      startDate: DateTime.utc(2026, 11, 10),
      status: CarePlanStatus.draft,
      createdAt: DateTime.utc(2026, 11, 8),
    ),
  ];

  @override
  Future<List<ContentResourceOption>> getAvailableResources() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeProgress implements ProgressRepository {
  @override
  Future<AdherenceSummary> getPatientProgress(
    String patientId, {
    int days = 7,
  }) async => AdherenceSummary(
    days: [
      AdherenceDay(
        date: DateTime.utc(2026, 11, 8),
        total: 4,
        completed: 3,
        skipped: 1,
        snoozed: 0,
        pending: 0,
        missed: 0,
      ),
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
