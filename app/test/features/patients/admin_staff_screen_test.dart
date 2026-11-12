import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/router/app_router.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:sukun_life/features/patients/presentation/admin_staff_screen.dart';

class _FakeStaff implements StaffRepository {
  final rows = <Map<String, dynamic>>[];
  final added = <Map<String, String?>>[];
  final removed = <String>[];

  @override
  Future<List<Map<String, dynamic>>> list() async => List.of(rows);

  @override
  Future<void> add({String? email, String? phone, String? name}) async {
    added.add({'email': email, 'phone': phone, 'name': name});
    rows.add({'id': 'n${rows.length}', 'display_name': name, 'email': email});
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    rows.removeWhere((row) => row['id'] == id);
  }
}

void main() {
  test('a raqi is staff but not the main admin', () {
    const raqi = AppSession(role: UserRole.raqi, userId: 'r');
    expect(raqi.isStaff, isTrue);
    expect(raqi.isSuperAdmin, isFalse);
    expect(UserRole.fromDatabaseValue('raqi'), UserRole.raqi);
  });

  test('content, templates, notices and staff stay main-admin only', () {
    for (final path in [
      '/admin/content',
      '/admin/content/new',
      '/admin/care-templates',
      '/admin/routine-templates',
      '/admin/announcements',
      '/admin/staff',
      '/admin/library',
      '/admin/patients/new',
      '/admin/patients/p1/prescriptions/new',
      '/admin/patients/p1/plans/x/actions/suggest',
    ]) {
      expect(isSuperAdminOnlyPath(path), isTrue, reason: path);
    }
    for (final path in [
      '/admin/dashboard',
      '/admin/users',
      '/admin/user-routines',
      '/admin/patients',
      '/admin/patients/p1',
      '/admin/patients/p1/plans/x',
    ]) {
      expect(isSuperAdminOnlyPath(path), isFalse, reason: path);
    }
  });

  testWidgets('main admin adds a raqi by Gmail and removes them', (
    tester,
  ) async {
    final repository = _FakeStaff();
    await tester.pumpWidget(
      MaterialApp(home: AdminStaffScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('এখনো কোনো রাকি নেই'), findsOneWidget);

    await tester.tap(find.byKey(const Key('staff-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('staff-name')), 'Raqi One');
    await tester.enterText(
      find.byKey(const Key('staff-email')),
      'raqi.one@gmail.com',
    );
    await tester.tap(find.byKey(const Key('staff-save')));
    await tester.pumpAndSettle();
    expect(repository.added.single['email'], 'raqi.one@gmail.com');
    expect(find.text('Raqi One'), findsOneWidget);

    await tester.tap(find.byTooltip('সরান'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'সরান'));
    await tester.pumpAndSettle();
    expect(repository.removed, ['n0']);
  });

  testWidgets('a short phone number is refused before saving', (tester) async {
    final repository = _FakeStaff();
    await tester.pumpWidget(
      MaterialApp(home: AdminStaffScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('staff-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('staff-phone')), '01712');
    await tester.tap(find.byKey(const Key('staff-save')));
    await tester.pumpAndSettle();
    expect(repository.added, isEmpty);
  });
}
