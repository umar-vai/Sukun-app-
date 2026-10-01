import 'package:sukun_life/core/auth/user_role.dart';

class AppSession {
  const AppSession({required this.role, this.userId, this.displayName});

  const AppSession.guest()
    : role = UserRole.guest,
      userId = null,
      displayName = null;

  final UserRole role;
  final String? userId;
  final String? displayName;

  bool get isAuthenticated => userId != null;
  bool get isPatient => role == UserRole.patient;
  bool get isSuperAdmin => role == UserRole.superAdmin;
}
