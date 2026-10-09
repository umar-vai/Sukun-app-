import 'package:sukun_life/core/auth/user_role.dart';

class AppSession {
  const AppSession({
    required this.role,
    this.userId,
    this.displayName,
    this.requiresCredentialChange = false,
  });

  const AppSession.guest()
    : role = UserRole.guest,
      userId = null,
      displayName = null,
      requiresCredentialChange = false;

  final UserRole role;
  final String? userId;
  final String? displayName;
  final bool requiresCredentialChange;

  bool get isAuthenticated => userId != null;
  bool get isMember => isAuthenticated && role == UserRole.member;
  bool get isPatient => role == UserRole.patient;
  bool get isSuperAdmin => role == UserRole.superAdmin;
}
