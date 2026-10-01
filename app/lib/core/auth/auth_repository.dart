import 'package:sukun_life/core/auth/app_session.dart';

abstract interface class AuthRepository {
  Stream<AppSession> watchSession();

  Future<void> signOut();
}

final class GuestAuthRepository implements AuthRepository {
  const GuestAuthRepository();

  @override
  Stream<AppSession> watchSession() => Stream.value(const AppSession.guest());

  @override
  Future<void> signOut() async {}
}
