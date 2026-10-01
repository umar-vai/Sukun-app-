import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/auth/user_role.dart';

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
}
