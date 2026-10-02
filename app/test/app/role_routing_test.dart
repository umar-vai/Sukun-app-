import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_providers.dart';
import 'package:sukun_life/features/patient_care/data/patient_care_repository.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';

void main() {
  testWidgets('guest sees public home without patient data', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => Stream.value(const AppSession.guest()),
          ),
        ],
        child: const SukunLifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calm support for faith and care'), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsNothing);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('patient session is routed to patient home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => Stream.value(
              const AppSession(
                role: UserRole.patient,
                userId: 'patient-user',
                displayName: 'Rahim',
              ),
            ),
          ),
          patientCareRepositoryProvider.overrideWithValue(
            const _EmptyPatientCareRepository(),
          ),
        ],
        child: const SukunLifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assalamu Alaikum, Rahim'), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsNothing);
  });

  testWidgets('super admin session is routed to admin dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => Stream.value(
              const AppSession(
                role: UserRole.superAdmin,
                userId: 'admin-user',
                displayName: 'Admin',
              ),
            ),
          ),
        ],
        child: const SukunLifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('Welcome, Admin'), findsOneWidget);
  });

  testWidgets('patient with temporary credentials is forced to reset them', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => Stream.value(
              const AppSession(
                role: UserRole.patient,
                userId: 'patient-user',
                displayName: 'Rahim',
                requiresCredentialChange: true,
              ),
            ),
          ),
        ],
        child: const SukunLifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create your private password'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
  });
}

final class _EmptyPatientCareRepository implements PatientCareRepository {
  const _EmptyPatientCareRepository();

  @override
  Future<CarePlan?> getActivePlan() async => null;

  @override
  Future<List<PlanAction>> getActivePlanActions(String planId) async => [];

  @override
  Future<PatientDay> getToday() async => const PatientDay(tasks: []);

  @override
  Future<List<Prescription>> getVisiblePrescriptions() async => [];

  @override
  Future<PatientTask> recordTask({
    required PatientTask task,
    required PatientTaskStatus status,
    required String clientEventId,
    DateTime? snoozedUntil,
    String? skipReason,
  }) => throw UnimplementedError();
}
