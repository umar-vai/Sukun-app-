import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/domain/prescription_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads one user's routines through the audited Super Admin RPC. Each
/// routine says whether an admin set it (`assigned_by_admin`).
typedef RoutineOverviewLoader = Future<List<Map<String, dynamic>>> Function(
  String userId,
);

final routineOverviewLoaderProvider = Provider<RoutineOverviewLoader>((ref) {
  return (userId) async {
    final raw = await Supabase.instance.client.rpc(
      'admin_get_user_routine_overview',
      params: {'p_target_user_id': userId},
    );
    final routines = raw is Map ? raw['routines'] : null;
    if (routines is! List) return const [];
    return [
      for (final routine in routines)
        if (routine is Map) Map<String, dynamic>.from(routine),
    ];
  };
});

/// What the admin/raqi gave, and what the person added for themselves.
final class PrescriptionOverview {
  const PrescriptionOverview({
    required this.adminSections,
    required this.selfSections,
  });

  final List<PrescriptionSection> adminSections;

  /// Empty when the person added nothing; the UI then hides that section.
  final List<PrescriptionSection> selfSections;

  bool get isEmpty => adminSections.isEmpty && selfSections.isEmpty;
}

/// Builds the overview from the active care plan (patients) and the user's
/// active routines. Only active, non-rejected items are included.
Future<PrescriptionOverview> loadPrescriptionOverview({
  required CarePlansRepository carePlans,
  required RoutineOverviewLoader routines,
  List<CarePlan> plans = const [],
  String? userId,
}) async {
  final adminEntries = <PrescriptionEntry>[];
  final selfEntries = <PrescriptionEntry>[];

  for (final plan in plans) {
    if (plan.status != CarePlanStatus.active) continue;
    for (final action in await carePlans.getActions(plan.id)) {
      if (action.reviewStatus != ActionReviewStatus.approved) continue;
      adminEntries.add(entryFromPlanAction(action));
    }
  }

  if (userId != null && userId.isNotEmpty) {
    for (final routine in await routines(userId)) {
      if (routine['is_active'] != true) continue;
      final target = routine['assigned_by_admin'] == true
          ? adminEntries
          : selfEntries;
      for (final action in routine['actions'] as List? ?? const []) {
        if (action is! Map || action['is_active'] == false) continue;
        target.add(entryFromRoutineAction(Map<String, dynamic>.from(action)));
      }
    }
  }

  return PrescriptionOverview(
    adminSections: groupPrescription(adminEntries),
    selfSections: groupPrescription(selfEntries),
  );
}
