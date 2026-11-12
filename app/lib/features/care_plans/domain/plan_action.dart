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

enum ActionFrequencyType { daily, weekly, dates }

/// The three bath (ghusl) kinds an admin places on a calendar per patient
/// (owner request 2026-11-12). On a detox day every other reminder and task
/// of that person is paused; only the detox bath and its linked content run.
enum GhuslKind {
  nazar('nazar', 'বদনজরের গোসল', 'b01'),
  boroi('boroi', 'বরই পাতার গোসল', 'b02'),
  detox('detox', 'ডিটক্স গোসল', 'b03');

  const GhuslKind(this.databaseValue, this.label, this.templateId);

  final String databaseValue;
  final String label;

  /// The Sukun official template this calendar kind fills.
  final String templateId;

  static GhuslKind? fromDatabase(Object? value) {
    for (final kind in values) {
      if (kind.databaseValue == value) return kind;
    }
    return null;
  }

  static GhuslKind? forTemplate(String? templateId) {
    for (final kind in values) {
      if (kind.templateId == templateId) return kind;
    }
    return null;
  }
}

/// Most calendar dates one action may carry (server limit).
const maxActionDates = 120;

class ActionFrequency {
  const ActionFrequency.daily({this.interval = 1})
    : type = ActionFrequencyType.daily,
      weekdays = const {},
      dates = const {},
      ghusl = null;

  const ActionFrequency.weekly(this.weekdays)
    : type = ActionFrequencyType.weekly,
      interval = 1,
      dates = const {},
      ghusl = null;

  /// Runs only on the given calendar dates (local, time ignored).
  const ActionFrequency.dates(this.dates, {this.ghusl})
    : type = ActionFrequencyType.dates,
      interval = 1,
      weekdays = const {};

  factory ActionFrequency.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'weekly') {
      final values = (json['weekdays'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .where((value) => value >= 1 && value <= 7)
          .toSet();
      return ActionFrequency.weekly(values);
    }
    if (json['type'] == 'dates') {
      final values = <DateTime>{};
      for (final raw in json['dates'] as List<dynamic>? ?? const []) {
        final parsed = DateTime.tryParse(raw.toString());
        if (parsed != null) {
          values.add(DateTime(parsed.year, parsed.month, parsed.day));
        }
      }
      return ActionFrequency.dates(
        values,
        ghusl: GhuslKind.fromDatabase(json['ghusl']),
      );
    }
    return ActionFrequency.daily(interval: json['interval'] as int? ?? 1);
  }

  final ActionFrequencyType type;
  final int interval;
  final Set<int> weekdays;
  final Set<DateTime> dates;
  final GhuslKind? ghusl;

  List<DateTime> get sortedDates => dates.toList()..sort();

  Map<String, dynamic> toJson() => switch (type) {
    ActionFrequencyType.daily => {'type': 'daily', 'interval': interval},
    ActionFrequencyType.weekly => {
      'type': 'weekly',
      'weekdays': weekdays.toList()..sort(),
    },
    ActionFrequencyType.dates => {
      'type': 'dates',
      'dates': [for (final date in sortedDates) isoDate(date)],
      'ghusl': ?ghusl?.databaseValue,
    },
  };

  String get label => switch (type) {
    ActionFrequencyType.daily =>
      interval == 1 ? 'Daily' : 'Every $interval days',
    ActionFrequencyType.weekly => () {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final ordered = weekdays.toList()..sort();
      return ordered.map((day) => names[day - 1]).join(', ');
    }(),
    ActionFrequencyType.dates => '${dates.length} dates',
  };
}

/// `YYYY-MM-DD` for a local calendar date.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class LinkedResource {
  const LinkedResource({
    required this.id,
    required this.title,
    required this.type,
    this.sortOrder = 0,
    this.usageNote,
    this.titleBn,
    this.mediaSourceType,
    this.mediaUrl,
    this.youtubeVideoId,
    this.thumbnailUrl,
    this.rightsNote,
    this.publicRoute,
  });

  final String id;
  final String title;
  final String? titleBn;
  final String type;
  final int sortOrder;
  final String? usageNote;
  final String? mediaSourceType;
  final String? mediaUrl;
  final String? youtubeVideoId;
  final String? thumbnailUrl;
  final String? rightsNote;
  final String? publicRoute;

  bool get canOpen {
    if (mediaSourceType == 'youtube') {
      return youtubeVideoId?.trim().isNotEmpty == true;
    }
    return publicRoute != null || mediaUrl?.trim().isNotEmpty == true;
  }
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
    this.resources = const [],
    this.notificationTitle,
  });

  factory PlanAction.fromJson(Map<String, dynamic> json) {
    final relations = json['plan_action_resources'] as List<dynamic>?;
    final resources = <LinkedResource>[];
    for (final entry in relations ?? const <dynamic>[]) {
      final relation = entry as Map<String, dynamic>;
      final item = relation['content_items'] as Map<String, dynamic>?;
      if (item == null) continue;
      // Never expose unpublished/staff-only media through patient plan UI.
      if (item['status'] != 'published' ||
          !const [
            'public',
            'patient_only',
            'assigned_only',
          ].contains(item['visibility'])) {
        continue;
      }
      resources.add(
        LinkedResource(
          id: item['id'] as String,
          title: item['title'] as String,
          titleBn: item['title_bn'] as String?,
          type: item['type'] as String,
          sortOrder: relation['sort_order'] as int? ?? 0,
          usageNote: relation['usage_note'] as String?,
          mediaSourceType: item['media_source_type'] as String?,
          mediaUrl: item['media_url'] as String?,
          youtubeVideoId: item['youtube_video_id'] as String?,
          thumbnailUrl: item['thumbnail_url'] as String?,
          rightsNote: item['rights_note'] as String?,
        ),
      );
    }
    for (final entry
        in json['plan_action_quran_surahs'] as List<dynamic>? ?? const []) {
      final row = entry as Map<String, dynamic>;
      final number = row['surah_number'];
      final title = row['title'];
      if (number is! int ||
          number < 1 ||
          number > 114 ||
          title is! String ||
          title.trim().isEmpty) {
        continue;
      }
      resources.add(
        LinkedResource(
          id: 'quran:$number',
          title: title,
          titleBn: title,
          type: 'quran',
          sortOrder: row['sort_order'] as int? ?? 0,
          publicRoute: '/resources/quran/$number',
        ),
      );
    }
    resources.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order != 0 ? order : a.title.compareTo(b.title);
    });

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
      resource: resources.isEmpty ? null : resources.first,
      resources: List.unmodifiable(resources),
      notificationTitle: _blankToNull(json['notification_title'] as String?),
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
  final List<LinkedResource> resources;

  /// Short name the phone shows when this reminder fires. Null means the
  /// generic reminder text.
  final String? notificationTitle;

  List<LinkedResource> get linkedResources => resources.isNotEmpty
      ? resources
      : (resource == null ? const [] : [resource!]);
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

DateTime? _parseDate(String? value) =>
    value == null ? null : DateTime.tryParse(value);

DateTime? _parseTime(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  return DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
}
