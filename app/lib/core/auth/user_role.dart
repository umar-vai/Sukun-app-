enum UserRole {
  guest('guest'),
  member('member'),
  patient('patient'),

  /// Care staff added by the main admin: patients and reminders only.
  raqi('raqi'),
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
