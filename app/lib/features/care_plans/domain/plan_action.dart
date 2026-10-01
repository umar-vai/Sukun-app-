enum ActionReviewStatus {
  draft,
  needsReview,
  approved,
  rejected;

  String get databaseValue => switch (this) {
    ActionReviewStatus.draft => 'draft',
    ActionReviewStatus.needsReview => 'needs_review',
    ActionReviewStatus.approved => 'approved',
    ActionReviewStatus.rejected => 'rejected',
  };

  String get label => switch (this) {
    ActionReviewStatus.draft => 'Draft',
    ActionReviewStatus.needsReview => 'Needs review',
    ActionReviewStatus.approved => 'Approved',
    ActionReviewStatus.rejected => 'Rejected',
  };

  static ActionReviewStatus fromDatabase(String? value) {
    return switch (value) {
      'needs_review' => ActionReviewStatus.needsReview,
      'approved' => ActionReviewStatus.approved,
      'rejected' => ActionReviewStatus.rejected,
      _ => ActionReviewStatus.draft,
    };
  }
}

enum ActionFrequencyType { daily, weekly }

class ActionFrequency {
  const ActionFrequency.daily({this.interval = 1})
    : type = ActionFrequencyType.daily,
      weekdays = const {};

  const ActionFrequency.weekly(this.weekdays)
    : type = ActionFrequencyType.weekly,
      interval = 1;

  factory ActionFrequency.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'weekly') {
      final values = (json['weekdays'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .where((value) => value >= 1 && value <= 7)
          .toSet();
      return ActionFrequency.weekly(values);
    }
    return ActionFrequency.daily(interval: json['interval'] as int? ?? 1);
  }

  final ActionFrequencyType type;
  final int interval;
  final Set<int> weekdays;

  Map<String, dynamic> toJson() => switch (type) {
    ActionFrequencyType.daily => {'type': 'daily', 'interval': interval},
    ActionFrequencyType.weekly => {
      'type': 'weekly',
      'weekdays': weekdays.toList()..sort(),
    },
  };

  String get label {
    if (type == ActionFrequencyType.daily) {
      return interval == 1 ? 'Daily' : 'Every $interval days';
    }
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final ordered = weekdays.toList()..sort();
    return ordered.map((day) => names[day - 1]).join(', ');
  }
}

class LinkedResource {
  const LinkedResource({
    required this.id,
    required this.title,
    required this.type,
    this.usageNote,
    this.titleBn,
  });

  final String id;
  final String title;
  final String? titleBn;
  final String type;
  final String? usageNote;
}

class PlanAction {
  const PlanAction({
    required this.id,
    required this.carePlanId,
    required this.type,
    required this.title,
    required this.frequency,
    required this.startDate,
    required this.sortOrder,
    required this.reviewStatus,
    required this.reminderEnabled,
    this.instruction,
    this.countTarget,
    this.durationMinutes,
    this.timeWindow,
    this.exactTime,
    this.endDate,
    this.resource,
  });

  factory PlanAction.fromJson(Map<String, dynamic> json) {
    final relations = json['plan_action_resources'] as List<dynamic>?;
    LinkedResource? resource;
    if (relations?.isNotEmpty == true) {
      final relation = relations!.first as Map<String, dynamic>;
      final item = relation['content_items'] as Map<String, dynamic>?;
      if (item != null) {
        resource = LinkedResource(
          id: item['id'] as String,
          title: item['title'] as String,
          titleBn: item['title_bn'] as String?,
          type: item['type'] as String,
          usageNote: relation['usage_note'] as String?,
        );
      }
    }

    return PlanAction(
      id: json['id'] as String,
      carePlanId: json['care_plan_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      instruction: json['instruction'] as String?,
      countTarget: json['count_target'] as int?,
      durationMinutes: json['duration_minutes'] as int?,
      frequency: ActionFrequency.fromJson(
        Map<String, dynamic>.from(json['frequency_rule'] as Map),
      ),
      timeWindow: json['time_window'] as String?,
      exactTime: _parseTime(json['exact_time'] as String?),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: _parseDate(json['end_date'] as String?),
      sortOrder: json['sort_order'] as int,
      reviewStatus: ActionReviewStatus.fromDatabase(
        json['review_status'] as String?,
      ),
      reminderEnabled: json['reminder_enabled'] as bool? ?? false,
      resource: resource,
    );
  }

  final String id;
  final String carePlanId;
  final String type;
  final String title;
  final String? instruction;
  final int? countTarget;
  final int? durationMinutes;
  final ActionFrequency frequency;
  final String? timeWindow;
  final DateTime? exactTime;
  final DateTime startDate;
  final DateTime? endDate;
  final int sortOrder;
  final ActionReviewStatus reviewStatus;
  final bool reminderEnabled;
  final LinkedResource? resource;
}

DateTime? _parseDate(String? value) =>
    value == null ? null : DateTime.tryParse(value);

DateTime? _parseTime(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  return DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
}
