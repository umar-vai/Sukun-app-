import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/auth/user_role.dart';

void main() {
  test('database role values map to the supported application roles', () {
    expect(UserRole.fromDatabaseValue('guest'), UserRole.guest);
    expect(UserRole.fromDatabaseValue('member'), UserRole.member);
    expect(UserRole.fromDatabaseValue('raqi'), UserRole.raqi);
    expect(UserRole.fromDatabaseValue('support_staff'), UserRole.supportStaff);
    expect(UserRole.fromDatabaseValue('patient'), UserRole.patient);
    expect(UserRole.fromDatabaseValue('super_admin'), UserRole.superAdmin);
  });

  test('unknown and missing roles have guest-only access', () {
    expect(UserRole.fromDatabaseValue('practitioner'), UserRole.guest);
    expect(UserRole.fromDatabaseValue(null), UserRole.guest);
  });
}
