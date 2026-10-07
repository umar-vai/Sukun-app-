import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_launch_screen.dart';
import 'package:sukun_life/features/auth/presentation/login_screen.dart';
import 'package:sukun_life/features/auth/presentation/change_password_screen.dart';
import 'package:sukun_life/features/care_plans/presentation/care_plan_builder_screen.dart';
import 'package:sukun_life/features/care_plans/presentation/ai_action_review_screen.dart';
import 'package:sukun_life/features/care_plans/presentation/care_plan_preview_screen.dart';
import 'package:sukun_life/features/care_plans/presentation/create_care_plan_screen.dart';
import 'package:sukun_life/features/care_plans/presentation/plan_action_editor_screen.dart';
import 'package:sukun_life/features/content_admin/presentation/admin_content_editor_screen.dart';
import 'package:sukun_life/features/content_admin/presentation/admin_content_collections_screen.dart';
import 'package:sukun_life/features/content_admin/presentation/admin_content_list_screen.dart';
import 'package:sukun_life/features/content_admin/presentation/admin_content_preview_screen.dart';
import 'package:sukun_life/features/home/presentation/role_home_screens.dart';
import 'package:sukun_life/features/islamic_utilities/presentation/prayer_settings_screen.dart';
import 'package:sukun_life/features/islamic_utilities/presentation/prayer_times_screen.dart';
import 'package:sukun_life/features/islamic_utilities/presentation/qibla_screen.dart';
import 'package:sukun_life/features/patient_care/presentation/my_plan_screen.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_home_screen.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_profile_screen.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_progress_screen.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';
import 'package:sukun_life/features/patients/presentation/create_patient_screen.dart';
import 'package:sukun_life/features/patients/presentation/create_prescription_screen.dart';
import 'package:sukun_life/features/patients/presentation/patient_detail_screen.dart';
import 'package:sukun_life/features/patients/presentation/patients_list_screen.dart';
import 'package:sukun_life/features/resources/presentation/resource_detail_screen.dart';
import 'package:sukun_life/features/resources/presentation/resource_browse_screens.dart';
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
      final isCredentialRoute = path == '/patient/change-password';

      if (!session.isAuthenticated && (isPatientRoute || isAdminRoute)) {
        return '/login';
      }
      if (isAdminRoute && !session.isSuperAdmin) {
        return session.isPatient ? '/patient/home' : '/';
      }
      if (isPatientRoute && !session.isPatient) {
        return session.isSuperAdmin ? '/admin/dashboard' : '/';
      }
      if (session.isPatient && session.requiresCredentialChange) {
        return isCredentialRoute ? null : '/patient/change-password';
      }
      if (isCredentialRoute && !session.requiresCredentialChange) {
        return '/patient/home';
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
        path: '/prayer-times',
        builder: (context, state) => const PrayerTimesScreen(),
        routes: [
          GoRoute(
            path: 'settings',
            builder: (context, state) => const PrayerSettingsScreen(),
          ),
        ],
      ),
      GoRoute(path: '/qibla', builder: (context, state) => const QiblaScreen()),
      GoRoute(
        path: '/resources',
        builder: (context, state) => ResourcesHomeScreen(
          initialSectionSlug: state.uri.queryParameters['section'],
        ),
        routes: [
          GoRoute(
            path: 'quran',
            builder: (context, state) => const QuranBrowserScreen(),
            routes: [
              GoRoute(
                path: 'collections',
                builder: (context, state) => const QuranCollectionsScreen(),
                routes: [
                  GoRoute(
                    path: ':collectionId',
                    builder: (context, state) => QuranCollectionDetailScreen(
                      collectionId: state.pathParameters['collectionId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: ':surahNumber',
                builder: (context, state) => QuranSurahScreen(
                  surahNumber: int.parse(state.pathParameters['surahNumber']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'hadith',
            builder: (context, state) => const HadithBrowserScreen(),
          ),
          GoRoute(
            path: 'dua-azkar',
            builder: (context, state) =>
                const TaxonomyBrowserScreen(kind: TaxonomyKind.duaAzkar),
          ),
          GoRoute(
            path: 'ruqyah',
            builder: (context, state) =>
                const TaxonomyBrowserScreen(kind: TaxonomyKind.ruqyah),
          ),
          GoRoute(
            path: ':resourceId',
            builder: (context, state) => ResourceDetailScreen(
              resourceId: state.pathParameters['resourceId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/patient/home',
        builder: (context, state) => PatientHomeScreen(
          displayName: _patientSession(session)?.displayName,
        ),
      ),
      GoRoute(
        path: '/patient/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/patient/plan',
        builder: (context, state) => const MyPlanScreen(),
      ),
      GoRoute(
        path: '/patient/resources',
        builder: (context, state) => PatientScaffold(
          title: 'Islamic Resources',
          selectedIndex: 2,
          body: ResourcesHomeScreen(
            initialSectionSlug: state.uri.queryParameters['section'],
            embedded: true,
          ),
        ),
      ),
      GoRoute(
        path: '/patient/progress',
        builder: (context, state) => const PatientProgressScreen(),
      ),
      GoRoute(
        path: '/patient/resources/:resourceId',
        builder: (context, state) => ResourceDetailScreen(
          resourceId: state.pathParameters['resourceId']!,
        ),
      ),
      GoRoute(
        path: '/patient/profile',
        builder: (context, state) => PatientProfileScreen(
          displayName: _patientSession(session)?.displayName,
        ),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) =>
            AdminHomeScreen(displayName: _adminSession(session)?.displayName),
      ),
      GoRoute(
        path: '/admin/patients',
        builder: (context, state) => const PatientsListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const CreatePatientScreen(),
          ),
          GoRoute(
            path: ':patientId',
            builder: (context, state) => PatientDetailScreen(
              patientId: state.pathParameters['patientId']!,
            ),
            routes: [
              GoRoute(
                path: 'prescriptions/new',
                builder: (context, state) => CreatePrescriptionScreen(
                  patientId: state.pathParameters['patientId']!,
                ),
              ),
              GoRoute(
                path: 'plans/new',
                builder: (context, state) => CreateCarePlanScreen(
                  patientId: state.pathParameters['patientId']!,
                  initialPrescriptionId:
                      state.uri.queryParameters['prescriptionId'],
                  copyFromPlanId: state.uri.queryParameters['copyFromPlanId'],
                ),
              ),
              GoRoute(
                path: 'plans/:planId',
                builder: (context, state) => CarePlanBuilderScreen(
                  patientId: state.pathParameters['patientId']!,
                  planId: state.pathParameters['planId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'preview',
                    builder: (context, state) => CarePlanPreviewScreen(
                      patientId: state.pathParameters['patientId']!,
                      planId: state.pathParameters['planId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'actions/suggest',
                    builder: (context, state) => AiActionReviewScreen(
                      patientId: state.pathParameters['patientId']!,
                      planId: state.pathParameters['planId']!,
                      prescriptionId:
                          state.uri.queryParameters['prescriptionId'] ?? '',
                      initialSeed: state.extra is AiActionReviewSeed
                          ? state.extra! as AiActionReviewSeed
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: 'actions/new',
                    builder: (context, state) => PlanActionEditorScreen(
                      planId: state.pathParameters['planId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'actions/:actionId',
                    builder: (context, state) => PlanActionEditorScreen(
                      planId: state.pathParameters['planId']!,
                      actionId: state.pathParameters['actionId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin/content',
        builder: (context, state) => const AdminContentListScreen(),
        routes: [
          GoRoute(
            path: 'collections',
            builder: (context, state) => const AdminContentCollectionsScreen(),
          ),
          GoRoute(
            path: 'new',
            builder: (context, state) => const AdminContentEditorScreen(),
          ),
          GoRoute(
            path: ':contentItemId/preview',
            builder: (context, state) => AdminContentPreviewScreen(
              contentItemId: state.pathParameters['contentItemId']!,
            ),
          ),
          GoRoute(
            path: ':contentItemId/edit',
            builder: (context, state) => AdminContentEditorScreen(
              contentItemId: state.pathParameters['contentItemId']!,
            ),
          ),
        ],
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
      loading: () => const SukunLaunchScreen(),
      error: (error, stackTrace) => const Scaffold(
        body: AppErrorState(
          message: 'We could not verify your session. Please try again.',
        ),
      ),
    );
  }
}
