import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

class PatientDay {
  const PatientDay({required this.tasks, this.activePlan});

  final CarePlan? activePlan;
  final List<PatientTask> tasks;

  int get completedCount =>
      tasks.where((task) => task.status == PatientTaskStatus.completed).length;

  double get completionRatio =>
      tasks.isEmpty ? 0 : completedCount / tasks.length;

  PatientTask? get nextTask {
    for (final task in tasks) {
      if (task.status.canUpdate) return task;
    }
    return null;
  }

  /// Show the next action only once: featured at the top, not repeated below.
  List<PatientTask> get remainingTasks {
    final featuredId = nextTask?.id;
    return List<PatientTask>.unmodifiable(
      tasks.where((task) => task.id != featuredId),
    );
  }

  PatientDay replaceTask(PatientTask updated) => PatientDay(
    activePlan: activePlan,
    tasks: [for (final task in tasks) task.id == updated.id ? updated : task],
  );
}
