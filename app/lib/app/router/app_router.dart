import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/features/auth/presentation/login_screen.dart';
import 'package:sukun_life/features/home/presentation/role_home_screens.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionState = ref.watch(appSessionProvider);
  final session = sessionState.value;

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (session == null) return null;

      final path = state.uri.path;
      final isPatientRoute = path.startsWith('/patient');
      final isAdminRoute = path.startsWith('/admin');
      final isLoginRoute = path == '/login';

      if (!session.isAuthenticated && (isPatientRoute || isAdminRoute)) {
        return '/login';
      }
      if (isAdminRoute && !session.isSuperAdmin) {
        return session.isPatient ? '/patient/home' : '/';
      }
      if (isPatientRoute && !session.isPatient) {
        return session.isSuperAdmin ? '/admin/dashboard' : '/';
      }
      if (isLoginRoute && session.isPatient) return '/patient/home';
      if (isLoginRoute && session.isSuperAdmin) return '/admin/dashboard';
      if (path == '/' && session.isPatient) return '/patient/home';
      if (path == '/' && session.isSuperAdmin) return '/admin/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            _SessionLanding(sessionState: sessionState),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/resources',
        builder: (context, state) => const ResourcesHomeScreen(),
      ),
      GoRoute(
        path: '/patient/home',
        builder: (context, state) => PatientHomeScreen(
          displayName: _patientSession(session)?.displayName,
        ),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) =>
            AdminHomeScreen(displayName: _adminSession(session)?.displayName),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: AppErrorState(
        message: state.error?.toString() ?? 'Page not found.',
      ),
    ),
  );
});

AppSession? _patientSession(AppSession? session) =>
    session?.isPatient == true ? session : null;

AppSession? _adminSession(AppSession? session) =>
    session?.isSuperAdmin == true ? session : null;

class _SessionLanding extends StatelessWidget {
  const _SessionLanding({required this.sessionState});

  final AsyncValue<AppSession> sessionState;

  @override
  Widget build(BuildContext context) {
    return sessionState.when(
      data: (_) => const GuestHomeScreen(),
      loading: () => const Scaffold(body: AppLoadingState()),
      error: (error, stackTrace) => const Scaffold(
        body: AppErrorState(
          message: 'We could not verify your session. Please try again.',
        ),
      ),
    );
  }
}
