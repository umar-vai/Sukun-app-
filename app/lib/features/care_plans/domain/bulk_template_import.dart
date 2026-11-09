import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';

/// A wall-clock reminder time (device local time).
final class ReminderClock implements Comparable<ReminderClock> {
  const ReminderClock(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  /// Care plan reminder windows understood by `save_plan_action`.
  String get timeWindow {
    if (hour >= 3 && hour < 11) return 'morning';
    if (hour >= 11 && hour < 16) return 'afternoon';
    if (hour >= 16 && hour < 20) return 'evening';
    return 'night';
  }

  String get slotLabel => switch (timeWindow) {
    'morning' => 'সকাল',
    'afternoon' => 'দুপুর',
    'evening' => 'সন্ধ্যা',
    _ => 'রাত',
  };

  /// `HH:mm:ss` for Postgres `time` columns.
  String get databaseValue =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:00';

  /// Bangla 12-hour label, for example "সকাল ৬:৩০".
  String get label {
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$slotLabel ${toBanglaDigits('$twelve')}:'
        '${toBanglaDigits(minute.toString().padLeft(2, '0'))}';
  }

  DateTime onDate(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  @override
  int compareTo(ReminderClock other) =>
      (hour * 60 + minute).compareTo(other.hour * 60 + other.minute);

  @override
  bool operator ==(Object other) =>
      other is ReminderClock && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

String toBanglaDigits(String value) {
  const digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  final buffer = StringBuffer();
  for (final unit in value.codeUnits) {
    final index = unit - 48;
    buffer.write(
      index >= 0 && index <= 9 ? digits[index] : String.fromCharCode(unit),
    );
  }
  return buffer.toString();
}

/// Suggested reminder times per official template. These are editable
/// starting points chosen by Sukun Life (owner decision 2026-11-09); the admin
/// sees every time before importing and can change or remove it.
const _morningEvening = [ReminderClock(6, 30), ReminderClock(17, 30)];
const _afterPrayers = [
  ReminderClock(5, 15),
  ReminderClock(13, 30),
  ReminderClock(16, 45),
  ReminderClock(18, 15),
  ReminderClock(20, 0),
];

const officialTemplateDefaultTimes = <String, List<ReminderClock>>{
  'a01': _morningEvening,
  'a02': [ReminderClock(22, 0)],
  'a03': [ReminderClock(7, 0)],
  'a04': _afterPrayers,
  'a05': _morningEvening,
  'a06': [ReminderClock(20, 30)],
  'a07': [ReminderClock(21, 0)],
  'a08': [ReminderClock(9, 0)],
  'a09': [ReminderClock(16, 30)],
  'a10': [ReminderClock(6, 45)],
  'a11': [ReminderClock(22, 15)],
  's01': [ReminderClock(8, 0)],
  's02': [ReminderClock(8, 15)],
  's03': [ReminderClock(7, 30), ReminderClock(19, 30)],
  's04': [ReminderClock(18, 0)],
  's05': [ReminderClock(9, 0)],
  's06': [ReminderClock(7, 0)],
  's07': [ReminderClock(21, 30)],
  's08': [ReminderClock(22, 0)],
  's09': [ReminderClock(20, 0)],
  's10': [ReminderClock(8, 0)],
  'u13': [ReminderClock(9, 0), ReminderClock(21, 0)],
  'x01': [ReminderClock(21, 0)],
  'x02': _afterPrayers,
  'x03': [ReminderClock(20, 30)],
  'x04': [ReminderClock(21, 0)],
  'x05': [ReminderClock(21, 30)],
  'x06': [ReminderClock(7, 30)],
  'x07': [ReminderClock(11, 0)],
  'x08': [ReminderClock(11, 0)],
};

List<ReminderClock> defaultTimesForTemplate(OfficialPrescriptionTemplate t) {
  final preset = officialTemplateDefaultTimes[t.id];
  if (preset != null) return List.of(preset);
  return switch (t.category) {
    'bath' => [const ReminderClock(10, 0)],
    'audio' => [const ReminderClock(21, 0)],
    _ => [const ReminderClock(8, 0)],
  };
}

List<ReminderClock> defaultTimesForResource(ContentResourceOption resource) =>
    switch (resource.type) {
      'audio' || 'video' => [const ReminderClock(21, 0)],
      _ => [const ReminderClock(7, 0)],
    };

/// Quick choices so admins tap instead of typing. Values still come only from
/// the admin; nothing is filled in for them.
const bulkVariableQuickValues = <String, List<int>>{
  'বার': [1, 3, 7, 11, 21, 33, 100],
  'দিন': [3, 7, 14, 21, 40],
  'মিনিট': [10, 15, 30, 45, 60],
};

const bulkDurationQuickValues = <int>[7, 14, 21, 40];

/// One row the admin (or user) selected in the bulk screen.
final class BulkImportItem {
  BulkImportItem.template(this.template, {List<ReminderClock>? times})
    : resource = null,
      times = times ?? defaultTimesForTemplate(template!),
      variables = {},
      resourceIds = [];

  BulkImportItem.resource(this.resource, {List<ReminderClock>? times})
    : template = null,
      times = times ?? defaultTimesForResource(resource!),
      variables = {},
      resourceIds = [resource!.id];

  final OfficialPrescriptionTemplate? template;
  final ContentResourceOption? resource;
  final List<ReminderClock> times;
  final Map<String, int> variables;

  /// Linked resources: CMS UUIDs or `quran:N` canonical chapters.
  final List<String> resourceIds;

  /// Empty means the reminder continues until the plan ends.
  int? durationDays;

  String get key =>
      template != null ? 't:${template!.id}' : 'r:${resource!.id}';

  String get title => template?.title ?? resource!.displayTitle;

  String get actionType => template?.actionType ?? resource!.type;

  String? get templateId => template?.id;

  List<String> get missingVariables => [
    for (final variable in template?.requiredVariables ?? const <String>[])
      if (variables[variable] == null) variable,
  ];

  bool get needsResource =>
      (template?.requiresLinkedResource ?? false) && resourceIds.isEmpty;

  bool get isReady =>
      times.isNotEmpty && missingVariables.isEmpty && !needsResource;

  /// Human readable reason this row blocks the import, or null.
  String? get problem {
    if (times.isEmpty) return 'অন্তত একটি সময় দিন';
    if (missingVariables.isNotEmpty) {
      return '${missingVariables.join(', ')} সংখ্যা বাছুন';
    }
    if (needsResource) return 'অডিও/সূরা যুক্ত করুন';
    return null;
  }

  String? get instruction {
    final source = template;
    if (source == null) return null;
    // Numbers the admin picked read in Bangla on the patient's screen and PDF.
    return toBanglaDigits(source.render(variables));
  }

  /// One reminder action per time. A suffix keeps titles distinct when the
  /// same item repeats during the day.
  List<BulkActionDraft> expand() {
    final ordered = [...times]..sort();
    final repeated = ordered.length > 1;
    return [
      for (final time in ordered)
        BulkActionDraft(
          title: repeated ? '$title (${time.slotLabel})' : title,
          type: actionType,
          instruction: instruction,
          time: time,
          resourceIds: List.unmodifiable(resourceIds),
          durationDays: durationDays,
          officialTemplateId: templateId,
        ),
    ];
  }
}

final class BulkActionDraft {
  const BulkActionDraft({
    required this.title,
    required this.type,
    required this.time,
    required this.resourceIds,
    this.instruction,
    this.durationDays,
    this.officialTemplateId,
  });

  final String title;
  final String type;
  final String? instruction;
  final ReminderClock time;
  final List<String> resourceIds;
  final int? durationDays;
  final String? officialTemplateId;

  List<String> get cmsResourceIds =>
      resourceIds.where((id) => !id.startsWith('quran:')).toList();

  List<int> get quranSurahNumbers => [
    for (final id in resourceIds)
      if (id.startsWith('quran:')) ?int.tryParse(id.substring(6)),
  ];

  /// Payload for `admin_import_user_routine_reminders`.
  Map<String, dynamic> toRoutineJson() => {
    'title': title.length > 160 ? title.substring(0, 160) : title,
    if (instruction != null) 'notes': instruction,
    if (officialTemplateId != null) 'official_template_id': officialTemplateId,
    'local_time': time.databaseValue,
    'resources': [
      for (final id in resourceIds)
        id.startsWith('quran:')
            ? {'provider': 'quran', 'external_resource_ref': id}
            : {'provider': 'cms', 'content_item_id': id},
    ],
  };
}

List<BulkActionDraft> expandBulkItems(Iterable<BulkImportItem> items) => [
  for (final item in items) ...item.expand(),
];

/// Best published match for a template that must link audio or a surah, so
/// the admin usually only confirms instead of searching. Returns null when
/// nothing clearly matches; the admin then picks one.
ContentResourceOption? suggestResourceForTemplate(
  OfficialPrescriptionTemplate template,
  List<ContentResourceOption> resources,
) {
  final keywords = _templateKeywords[template.id];
  if (keywords == null) return null;
  for (final keyword in keywords) {
    final needle = keyword.toLowerCase();
    if (needle.startsWith('quran:')) {
      for (final resource in resources) {
        if (resource.id == needle) return resource;
      }
      continue;
    }
    for (final resource in resources) {
      if (!resource.isLinkable) continue;
      if (template.category == 'audio' &&
          resource.type != 'audio' &&
          resource.canonicalSurahNumber == null) {
        continue;
      }
      final haystack = '${resource.title} ${resource.titleBn ?? ''}'
          .toLowerCase();
      if (haystack.contains(needle)) return resource;
    }
  }
  return null;
}

const _templateKeywords = <String, List<String>>{
  'a05': ['আয়াতুল কুরসি', 'ayatul kursi'],
  'a06': ['quran:2', 'বাকারা', 'baqarah'],
  'a07': ['বাকারা', 'baqarah', 'quran:2'],
  'b07': ['বদনজর', 'evil eye'],
  'b08': ['হিবশী', 'hibshi'],
  'u01': ['জিন', 'jinn'],
  'u02': ['হারক', 'harq'],
  'u03': ['কিতাল', 'qital'],
  'u04': ['শিফা', 'shifa'],
  'u05': ['খুরুজ', 'khuruj'],
  'u06': ['বদনজর', 'evil eye'],
  'u07': ['হিবশী', 'hibshi'],
  'u08': ['আট সূরা', '8 surah', 'eight surah'],
  'u09': ['তিন কুল', '3 qul', 'three qul'],
  'u10': ['আয়াতুল কুরসি', 'ayatul kursi'],
  'u11': ['ইদরিস', 'idris'],
  'u12': ['আজমী', 'ajmi', 'azmi'],
};
