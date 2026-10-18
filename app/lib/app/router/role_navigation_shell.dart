import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/app/router/shared_user_navigation.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

/// Keeps an exit and the role's primary destinations available on deep links.
/// Primary screens own their existing bottom bar; this shell fills the gaps.
class RoleNavigationShell extends StatelessWidget {
  const RoleNavigationShell({
    super.key,
    required this.path,
    required this.session,
    required this.child,
  });

  final String path;
  final AppSession? session;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!showsNavigationShell(path)) return child;

    final admin = session?.isSuperAdmin == true;
    final signedInUser =
        session?.isMember == true || session?.isPatient == true;
    final destinations = admin
        ? _adminDestinations
        : signedInUser
        ? sharedUserDestinations
        : _publicDestinations;
    final routes = admin
        ? _adminRoutes
        : signedInUser
        ? sharedUserRoutes
        : _publicRoutes;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: keyboardOpen
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (path != '/resources')
                  SafeArea(
                    top: false,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(
                        children: [
                          TextButton.icon(
                            key: const Key('navigation-back'),
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(navigationParent(path, session));
                              }
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('ফিরুন'),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            key: const Key('navigation-home'),
                            onPressed: () => context.go(routes.first),
                            icon: const Icon(Icons.home_outlined),
                            label: const Text('হোম'),
                          ),
                        ],
                      ),
                    ),
                  ),
                SukunBottomNavigation(
                  selectedIndex: navigationIndex(path, session),
                  destinations: destinations,
                  onSelected: (index) => context.go(routes[index]),
                ),
              ],
            ),
    );
  }
}

bool showsNavigationShell(String path) {
  if (path == '/' ||
      path == '/login' ||
      path.startsWith('/login/') ||
      path == '/register' ||
      path == '/patient/change-password') {
    return false;
  }
  return !{
    '/patient/home',
    '/patient/today',
    '/patient/plan',
    '/patient/resources',
    '/patient/progress',
    '/patient/profile',
    '/admin/dashboard',
    '/admin/patients',
    '/admin/content',
    '/admin/announcements',
  }.contains(path);
}

String navigationParent(String path, AppSession? session) {
  if (path == '/prayer-times/settings') return '/prayer-times';
  if (path.startsWith('/admin/announcements/')) return '/admin/announcements';
  if (path.startsWith('/admin/content/')) return '/admin/content';
  if (path.startsWith('/admin/patients/')) {
    final segments = path.split('/');
    if (segments.length > 6) return segments.take(6).join('/');
    if (segments.length > 4) return segments.take(4).join('/');
    return '/admin/patients';
  }
  if (path.startsWith('/announcements/')) return '/announcements';
  if (path.startsWith('/my-routines/action/')) return '/my-routines';
  if (path.startsWith('/resources/quran/collections/')) {
    return '/resources/quran/collections';
  }
  if (path.startsWith('/resources/quran/')) return '/resources/quran';
  if (path.startsWith('/resources/')) {
    return session?.isPatient == true ? '/patient/resources' : '/resources';
  }
  if (path.startsWith('/patient/resources/')) return '/patient/resources';
  if (session?.isSuperAdmin == true) return '/admin/dashboard';
  if (session?.isPatient == true) return '/patient/home';
  return '/';
}

int navigationIndex(String path, AppSession? session) {
  if (session?.isSuperAdmin == true) {
    if (path.startsWith('/admin/patients/')) return 1;
    if (path.startsWith('/admin/content/') || path.startsWith('/resources')) {
      return 2;
    }
    if (path.startsWith('/admin/announcements/') ||
        path.startsWith('/announcements')) {
      return 3;
    }
    return 0;
  }
  if (session?.isMember == true || session?.isPatient == true) {
    return sharedUserNavigationIndex(path);
  }
  if (path.startsWith('/resources')) return 0;
  if (path.startsWith('/announcements')) return 1;
  return 0;
}

const _adminRoutes = [
  '/admin/dashboard',
  '/admin/patients',
  '/admin/content',
  '/admin/announcements',
];
const _publicRoutes = ['/', '/announcements'];

const _adminDestinations = [
  SukunNavDestination(
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    label: 'হোম',
  ),
  SukunNavDestination(
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    label: 'রোগী',
  ),
  SukunNavDestination(
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
    label: 'উপকরণ',
  ),
  SukunNavDestination(
    icon: Icons.campaign_outlined,
    selectedIcon: Icons.campaign,
    label: 'নোটিশ',
  ),
];
const _publicDestinations = [
  SukunNavDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'হোম',
  ),
  SukunNavDestination(
    icon: Icons.campaign_outlined,
    selectedIcon: Icons.campaign,
    label: 'নোটিশ',
  ),
];
