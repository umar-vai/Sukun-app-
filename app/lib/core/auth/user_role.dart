enum UserRole {
  guest('guest'),
  member('member'),
  raqi('raqi'),
  supportStaff('support_staff'),
  patient('patient'),
  superAdmin('super_admin');

  const UserRole(this.databaseValue);

  final String databaseValue;

  static UserRole fromDatabaseValue(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.databaseValue == value,
      orElse: () => UserRole.guest,
    );
  }
}
