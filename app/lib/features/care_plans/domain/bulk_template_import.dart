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

/// The same Bangla letter can be stored as one code point (য়) or as two
/// (য + ়). Searching folds both to the two-part form so a typed word
/// always finds the template.
String foldBanglaForSearch(String value) => value
    .replaceAll('\u09DC', '\u09A1\u09BC')
    .replaceAll('\u09DD', '\u09A2\u09BC')
    .replaceAll('\u09DF', '\u09AF\u09BC');

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
  final saved = t.defaultTimes;
  if (saved != null && saved.isNotEmpty) return List.of(saved);
  final preset = t.defaultTimes == null
      ? officialTemplateDefaultTimes[t.id]
      : null;
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
      isCustom = false,
      times = times ?? defaultTimesForTemplate(template!),
      variables = {},
      resourceIds = [];

  /// A one-off row written for this person only, from a section's
  /// "নতুন যোগ করুন". [draft] is never saved as a Sukun template and its
  /// synthetic id is never sent to the server.
  BulkImportItem.custom(
    OfficialPrescriptionTemplate draft, {
    List<ReminderClock>? times,
  }) : template = draft,
       resource = null,
       isCustom = true,
       times = times ?? defaultTimesForTemplate(draft),
       variables = {},
       resourceIds = [];

  BulkImportItem.resource(this.resource, {List<ReminderClock>? times})
    : template = null,
      isCustom = false,
      times = times ?? defaultTimesForResource(resource!),
      variables = {},
      resourceIds = [resource!.id];

  final OfficialPrescriptionTemplate? template;
  final ContentResourceOption? resource;

  /// True for a row the admin or member wrote by hand for this import.
  final bool isCustom;
  final List<ReminderClock> times;
  final Map<String, int> variables;

  /// Linked resources: CMS UUIDs or `quran:N` canonical chapters.
  final List<String> resourceIds;

  /// Empty means the reminder continues until the plan ends.
  int? durationDays;

  /// What the phone shows when the reminder fires. Null or blank uses
  /// [defaultNotificationTitle]. The admin can edit it before importing.
  String? notificationTitle;

  /// Off saves the row without a phone reminder (it still shows in the
  /// person's daily list). Care plans only; routines are always on.
  bool reminderEnabled = true;

  /// The template's own reminder name when an admin set one, else the title.
  String get defaultNotificationTitle =>
      template?.notificationTitle?.trim().isNotEmpty == true
      ? template!.notificationTitle!.trim()
      : title;

  /// The name the reminder will actually carry.
  String get effectiveNotificationTitle {
    final custom = notificationTitle?.trim();
    final value = custom == null || custom.isEmpty
        ? defaultNotificationTitle
        : custom;
    return value.length > bulkMaxNotificationTitleLength
        ? value.substring(0, bulkMaxNotificationTitleLength)
        : value;
  }

  String get key => template != null
      ? '${isCustom ? 'c' : 't'}:${template!.id}'
      : 'r:${resource!.id}';

  String get title => template?.title ?? resource!.displayTitle;

  String get actionType => template?.actionType ?? resource!.type;

  /// Only real Sukun templates are referenced; custom rows carry none.
  String? get templateId => isCustom ? null : template?.id;

  List<String> get missingVariables => [
    for (final variable in template?.requiredVariables ?? const <String>[])
      if (variables[variable] == null) variable,
  ];

  bool get needsResource =>
      (template?.requiresLinkedResource ?? false) && resourceIds.isEmpty;

  bool get isReady =>
      times.isNotEmpty && missingVariables.isEmpty && !needsResource;

  /// Adds the curated library items once the library has loaded, for rows
  /// picked before it finished (the row would otherwise stay empty).
  void fillSuggestedResources(List<ContentResourceOption> library) {
    final source = template;
    if (source == null || isCustom || resourceIds.isNotEmpty) return;
    resourceIds.addAll(
      suggestResourcesForTemplate(source, library).map((r) => r.id),
    );
  }

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
          notificationTitle: effectiveNotificationTitle,
          reminderEnabled: reminderEnabled,
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
    this.notificationTitle,
    this.reminderEnabled = true,
  });

  final String title;
  final String type;
  final String? instruction;
  final ReminderClock time;
  final List<String> resourceIds;
  final int? durationDays;
  final String? officialTemplateId;

  /// Shown by the phone when the reminder fires.
  final String? notificationTitle;
  final bool reminderEnabled;

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
    if (notificationTitle != null) 'notification_title': notificationTitle,
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

/// Most linked resources one reminder may carry (server limit).
const bulkMaxResourcesPerItem = 16;

/// Longest reminder name the database accepts.
const bulkMaxNotificationTitleLength = 120;

/// Best published match for a template that must link audio or a surah, so
/// the admin usually only confirms instead of searching. Returns null when
/// nothing clearly matches; the admin then picks one.
ContentResourceOption? suggestResourceForTemplate(
  OfficialPrescriptionTemplate template,
  List<ContentResourceOption> resources,
) => suggestResourcesForTemplate(template, resources).firstOrNull;

/// Every library item that clearly belongs to a template: the audio, the
/// surah text and the matching Self Ruqyah guide section. Only resources the
/// app can actually link are returned, in the curated order, without
/// duplicates. The admin sees each one and can remove or add more.
List<ContentResourceOption> suggestResourcesForTemplate(
  OfficialPrescriptionTemplate template,
  List<ContentResourceOption> resources,
) {
  final linkable = [
    for (final resource in resources)
      if (resource.isLinkable) resource,
  ];
  final byId = {for (final resource in linkable) resource.id: resource};
  final bySlug = {
    for (final resource in linkable)
      if (resource.slug != null) resource.slug!: resource,
  };
  final result = <ContentResourceOption>[];
  void add(ContentResourceOption? resource) {
    if (resource == null || result.contains(resource)) return;
    if (result.length < bulkMaxResourcesPerItem) result.add(resource);
  }

  final refs =
      template.resourceRefs ??
      officialTemplateResourceRefs[template.id] ??
      const <String>[];
  for (final ref in refs) {
    add(ref.startsWith('quran:') ? byId[ref] : bySlug[ref]);
  }
  if (result.isEmpty) {
    // Older libraries without the curated slugs: fall back to a title match.
    add(_suggestByKeyword(template, linkable));
  }
  return result;
}

ContentResourceOption? _suggestByKeyword(
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

/// Curated links from each official template to published library items
/// (owner request 2026-11-09, completed 2026-11-10). Entries are CMS slugs or
/// canonical `quran:N` chapters; missing or unpublished ones are skipped.
///
/// Rule: when a template names a recitation, both forms are linked, the
/// text (Arabic ayat or surah) and the audio of the same recitation, so the
/// person can read or listen. Guide sections that explain the method come
/// first.
///
/// Not linked on purpose (owner decision 2026-11-10): a04 Tasbih-e-Fatemi,
/// a08 Durood, a09 Istighfar and x02 Ya Fattahu will open the planned dhikr
/// counter (see docs/BULK_TEMPLATE_IMPORT.md). a10, a11, u11, u13, x04, x05
/// and x08 name a dua, reciter or set the paper prescription decides, so the
/// admin picks.
const officialTemplateResourceRefs = <String, List<String>>{
  // আমল
  'a01': [
    'srg2024-c04-t033',
    'srg2024-aml-001',
    'srg2024-aml-002',
    _ayatulKursiText,
    _ayatulKursiAudio,
    ..._threeQulText,
    _threeQulAudio,
    'srg2024-dua-009',
    'srg2024-dua-010',
    'srg2024-dua-011',
    'srg2024-dua-012',
  ],
  'a02': [
    'srg2024-c04-t034',
    'srg2024-aml-003',
    'srg2024-aml-004',
    'srg2024-aml-005',
    _ayatulKursiText,
    _ayatulKursiAudio,
    'srg2024-aml-006',
    'srg2024-qur-006',
    'srg2024-aml-007',
    ..._threeQulText,
    _threeQulAudio,
    'srg2024-dua-013',
  ],
  'a03': ['srg2024-c04-t036', 'srg2024-dua-022'],
  'a05': [
    'srg2024-aml-005',
    _ayatulKursiText,
    _ayatulKursiAudio,
    'quran:113',
    'quran:114',
    _threeQulAudio,
  ],
  'a06': ['quran:2', 'sukun-ruqyahbd-baqara'],
  'a07': ['sukun-ruqyahbd-baqara', 'quran:2'],
  // সাপ্লিমেন্ট
  's01': [
    'srg2024-c03-t004',
    'srg2024-sup-001',
    'quran:1',
    'sukun-ruqyahbd-fatiha',
    _ayatulKursiText,
    _ayatulKursiAudio,
    ..._threeQulText,
    _threeQulAudio,
    'srg2024-c04-t011',
    'sukun-ruqyahbd-common-bangla',
  ],
  's02': [
    'srg2024-c03-t003',
    'srg2024-c04-t015',
    'sukun-ruqyahbd-sihr-hibshi',
    'srg2024-c04-t021',
    'sukun-ruqyahbd-shifa',
    'sukun-ruqyahbd-shifa-sakina',
    'srg2024-c04-t013',
    'sukun-ruqyahbd-harq',
    'srg2024-c04-t022',
    'sukun-ruqyahbd-qital-tadmir',
  ],
  's03': ['srg2024-sup-001', 'srg2024-c03-t004'],
  's04': ['srg2024-sup-001', 'srg2024-c03-t004'],
  's05': ['srg2024-sup-001', 'srg2024-c03-t027'],
  's06': ['srg2024-sup-002', 'srg2024-c03-t005'],
  's07': ['srg2024-sup-003', 'srg2024-c03-t006'],
  's08': ['srg2024-sup-010', 'srg2024-c03-t013'],
  's09': ['srg2024-sup-013', 'srg2024-c03-t016'],
  's10': ['srg2024-c03-t003', 'srg2024-sup-001'],
  // গোসল
  'b01': [
    'srg2024-ghs-002',
    'srg2024-c03-t028',
    'srg2024-c04-t014',
    'sukun-ruqyahbd-evil-eye',
  ],
  'b02': [
    'srg2024-ghs-003',
    'srg2024-c03-t029',
    'srg2024-sup-007',
    'srg2024-c04-t015',
    'sukun-ruqyahbd-sihr-hibshi',
  ],
  'b03': ['srg2024-ghs-004', 'srg2024-c03-t030'],
  'b04': [
    'srg2024-ghs-002',
    'srg2024-c03-t028',
    'srg2024-c04-t014',
    'sukun-ruqyahbd-evil-eye',
  ],
  'b05': ['srg2024-ghs-002', 'srg2024-ghs-003', 'srg2024-ghs-004'],
  'b06': ['srg2024-ghs-003', 'srg2024-ghs-004', 'srg2024-ghs-002'],
  'b07': ['sukun-ruqyahbd-evil-eye', 'srg2024-c04-t014', 'srg2024-ghs-002'],
  'b08': ['sukun-ruqyahbd-sihr-hibshi', 'srg2024-c04-t015', 'srg2024-ghs-003'],
  'b09': ['srg2024-c03-t027', 'srg2024-c03-t031'],
  // অডিও: audio first, then the ayat it recites
  'u01': ['sukun-ruqyahbd-jinn', 'srg2024-c04-t012'],
  'u02': ['sukun-ruqyahbd-harq', 'srg2024-c04-t013'],
  'u03': ['sukun-ruqyahbd-qital-tadmir', 'srg2024-c04-t022'],
  'u04': [
    'sukun-ruqyahbd-shifa-sakina',
    'sukun-ruqyahbd-shifa',
    'srg2024-c04-t021',
    'srg2024-c04-t026',
  ],
  'u05': ['sukun-ruqyahbd-khuruj', 'srg2024-c04-t024'],
  'u06': ['sukun-ruqyahbd-evil-eye', 'srg2024-c04-t014'],
  'u07': ['sukun-ruqyahbd-sihr-hibshi', 'srg2024-c04-t015', 'srg2024-c04-t016'],
  'u08': ['sukun-ruqyahbd-eight-surah'],
  'u09': [_threeQulAudio, ..._threeQulText],
  'u10': [_ayatulKursiAudio, _ayatulKursiText, 'srg2024-aml-005'],
  'u12': ['sukun-ruqyahbd-ajmy', ..._threeQulText, _ayatulKursiText],
  // বিশেষ আমল
  'x01': ['quran:60', 'quran:28', 'quran:25'],
  'x03': ['srg2024-c02-t005', 'srg2024-c04-t008'],
  'x06': ['srg2024-sup-001', 'srg2024-c03-t004'],
  'x07': ['srg2024-sup-006', 'srg2024-c03-t009'],
};

/// Ayatul Kursi (2:255) in the verified Self Ruqyah ayat set.
const _ayatulKursiText = 'srg2024-qur-005';
const _ayatulKursiAudio = 'sukun-ruqyahbd-ayatul-kursi';

/// Surah Ikhlas, Falaq and Nas as canonical chapters.
const _threeQulText = ['quran:112', 'quran:113', 'quran:114'];
const _threeQulAudio = 'sukun-ruqyahbd-three-kul';

/// Templates that will link to the planned dhikr counter instead of library
/// items (owner decision 2026-11-10). Not shown yet; kept so the counter can
/// wire itself to the right template later.
const officialTemplateDhikrRefs = <String, String>{
  'a04': 'tasbih-fatemi',
  'a08': 'durood',
  'a09': 'istighfar',
  'x02': 'ya-fattahu',
};

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

/// Prefix of the synthetic id a custom row's draft template carries.
const bulkCustomItemIdPrefix = 'custom-';

/// Builds the in-memory draft for a hand-written row in [category].
OfficialPrescriptionTemplate customBulkTemplate({
  required String id,
  required String category,
  required String title,
  required String instruction,
  List<ReminderClock>? times,
}) => OfficialPrescriptionTemplate(
  id: id,
  category: category,
  title: title.trim(),
  instruction: instruction.trim().isEmpty ? title.trim() : instruction.trim(),
  actionType: actionTypeForTemplateCategory(category),
  defaultTimes: times,
  resourceRefs: const [],
  // Audio still needs a linked audio before it can remind anyone.
  requiresResource: category == 'audio',
);
