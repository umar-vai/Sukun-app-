import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/personal_routines/data/personal_routine_repository.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/presentation/resource_picker_sheet.dart';
import 'package:sukun_life/features/personal_routines/domain/prayer_relative_reminder.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_routine_resource_prefill.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyRoutinesScreen extends ConsumerStatefulWidget {
  const MyRoutinesScreen({super.key, this.resourceId});

  final String? resourceId;

  @override
  ConsumerState<MyRoutinesScreen> createState() => _MyRoutinesScreenState();
}

class _MyRoutinesScreenState extends ConsumerState<MyRoutinesScreen> {
  late Future<_RoutinePageData> _data;
  bool _working = false;

  PersonalRoutineRepository get _repository =>
      PersonalRoutineRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _data = _load();
    if (mounted) setState(() {});
  }

  Future<_RoutinePageData> _load() async {
    final results = await Future.wait<Object>([
      _repository.listRoutines(),
      _repository.listActions(),
      _repository.todaysOutcomes(DateTime.now()),
    ]);
    return _RoutinePageData(
      routines: results[0] as List<Map<String, dynamic>>,
      actions: results[1] as List<Map<String, dynamic>>,
      outcomes: results[2] as Map<String, String>,
    );
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createRoutine() async {
    final controller = TextEditingController(text: 'আমার নতুন রুটিন');
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('নতুন রুটিন'),
        content: TextField(
          controller: controller,
          maxLength: 120,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'রুটিনের নাম'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('তৈরি করুন'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || _working) return;
    await _mutate(() => _repository.createRoutine(title));
  }

  Future<void> _mutate(Future<dynamic> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
      if (mounted) _refresh();
    } catch (_) {
      _notice('পরিবর্তনটি সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _editAction({
    required String routineId,
    Map<String, dynamic>? existing,
  }) async {
    final title = TextEditingController(
      text: existing?['title'] as String? ?? '',
    );
    final reminder = TextEditingController(
      text: existing?['notification_title'] as String? ?? '',
    );
    String kind = existing?['schedule_kind'] as String? ?? 'manual';
    int offset = existing?['prayer_offset_minutes'] as int? ?? 10;
    TimeOfDay? fixed;
    final previousTime = existing?['local_time'] as String?;
    if (previousTime != null && previousTime.length >= 5) {
      final pieces = previousTime.split(':');
      fixed = TimeOfDay(
        hour: int.tryParse(pieces[0]) ?? 22,
        minute: int.tryParse(pieces[1]) ?? 0,
      );
    }
    PersonalRoutineResourcePrefill? prefill;
    if (existing == null && widget.resourceId != null) {
      try {
        final content = await ref
            .read(resourcesRepositoryProvider)
            .getResource(widget.resourceId!);
        prefill = PersonalRoutineResourcePrefill.fromResource(content);
      } catch (_) {
        // Fail closed on inaccessible, unpublished or offline resource.
      }
      if (prefill == null) {
        _notice('এই প্রকাশিত রিসোর্সটি রুটিনে যুক্ত করা যাচ্ছে না।');
        title.dispose();
        reminder.dispose();
        return;
      }
      title.text = prefill.actionTitle;
      reminder.text = prefill.notificationTitle;
    }
    final settings = await ref.read(utilityPreferencesStoreProvider).load();
    final existingLinks = existing == null
        ? <Map<String, dynamic>>[]
        : await _repository.listActionResources(existing['id'] as String);
    final selectedIds = <String>[
      for (final item in existingLinks)
        if (item['provider'] == 'cms' && item['content_item_id'] is String)
          item['content_item_id'] as String,
    ];
    if (selectedIds.isEmpty && existing?['content_item_id'] is String) {
      selectedIds.add(existing!['content_item_id'] as String);
    }
    if (prefill != null && !selectedIds.contains(prefill.contentId)) {
      selectedIds.add(prefill.contentId);
    }
    final resourceRows = await Supabase.instance.client
        .from('content_items')
        .select('id,slug,title,title_bn,type,status,visibility,verification_status,media_source_type,media_url,category_id')
        .eq('status', 'published')
        .eq('visibility', 'public')
        .order('title');
    final resources = resourceRows
        .map((row) => ContentResourceOption.fromJson(row))
        .where((resource) => resource.isLinkable)
        .toList(growable: false);

    if (!mounted) {
      title.dispose();
      reminder.dispose();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(existing == null ? 'নতুন করণীয়' : 'করণীয় সম্পাদনা'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (prefill != null)
                    ListTile(
                      leading: const Icon(Icons.library_books_outlined),
                      title: Text(prefill.actionTitle),
                      subtitle: const Text(
                        'প্রকাশিত লাইব্রেরি রিসোর্স — নাম ও সময় সম্পাদনা করুন',
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'সংযুক্ত রিসোর্স (সর্বোচ্চ ১৬টি)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (var index = 0; index < selectedIds.length; index++)
                    Builder(builder: (context) {
                      final id = selectedIds[index];
                      final resource = resources.where((item) => item.id == id).firstOrNull;
                      return ListTile(
                        dense: true,
                        title: Text(resource?.displayTitle ?? 'রিসোর্স অনুপলব্ধ'),
                        subtitle: Text(resource?.type ?? 'Unavailable'),
                        leading: const Icon(Icons.library_books_outlined),
                        trailing: Wrap(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_upward_rounded),
                              tooltip: 'উপরে নিন',
                              onPressed: index == 0 ? null : () => update(() {
                                final moved = selectedIds.removeAt(index);
                                selectedIds.insert(index - 1, moved);
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward_rounded),
                              tooltip: 'নিচে নিন',
                              onPressed: index == selectedIds.length - 1
                                  ? null : () => update(() {
                                      final moved = selectedIds.removeAt(index);
                                      selectedIds.insert(index + 1, moved);
                                    }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'বাদ দিন',
                              onPressed: () => update(() => selectedIds.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    }),
                  OutlinedButton.icon(
                    onPressed: selectedIds.length >= 16 ? null : () async {
                      final id = await showResourcePickerSheet(
                        context: ctx,
                        resources: resources
                            .where((item) => !selectedIds.contains(item.id))
                            .toList(growable: false),
                        selectedId: '',
                      );
                      if (id != null && id.isNotEmpty &&
                          !selectedIds.contains(id) && ctx.mounted) {
                        update(() => selectedIds.add(id));
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('লাইব্রেরি থেকে রিসোর্স বাছুন'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: title,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'অ্যাকশনের নাম',
                    ),
                  ),
                  TextField(
                    controller: reminder,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'নোটিফিকেশনের শিরোনাম',
                      hintText: 'ঘুমানোর আগের আমল করতে ভুলবেন না',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'কখন করবেন?'),
                    items: const [
                      DropdownMenuItem(
                        value: 'manual',
                        child: Text('নিজে যখন চাই'),
                      ),
                      DropdownMenuItem(
                        value: 'fixed',
                        child: Text('নির্দিষ্ট সময়'),
                      ),
                      DropdownMenuItem(value: 'fajr', child: Text('ফজরের পরে')),
                      DropdownMenuItem(
                        value: 'maghrib',
                        child: Text('মাগরিবের পরে'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) update(() => kind = value);
                    },
                  ),
                  if (kind == 'fixed')
                    ListTile(
                      title: Text(
                        fixed == null ? 'সময় বেছে নিন' : fixed!.format(context),
                      ),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final chosen = await showTimePicker(
                          context: context,
                          initialTime:
                              fixed ?? const TimeOfDay(hour: 22, minute: 0),
                        );
                        if (chosen != null) update(() => fixed = chosen);
                      },
                    ),
                  if (kind == 'fajr' || kind == 'maghrib') ...[
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 5, label: Text('+৫ মিনিট')),
                        ButtonSegment(value: 10, label: Text('+১০ মিনিট')),
                      ],
                      selected: {offset == 5 ? 5 : 10},
                      onSelectionChanged: (next) =>
                          update(() => offset = next.single),
                    ),
                    if (!settings.isComplete)
                      const Text(
                        'প্রথমে নামাজের সময়ের সেটিংসে শহর ও পদ্ধতি নির্বাচন করুন।',
                      ),
                    if (settings.isComplete)
                      Text(
                        _prayerPreview(
                          settings: settings,
                          kind: kind,
                          offset: offset,
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'সময়সূচি সংরক্ষিত হবে। Background push delivery '
                    'এখনো পরীক্ষাধীন; notification নিশ্চিত নয়।',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('বাতিল'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty ||
                    reminder.text.trim().isEmpty ||
                    (kind == 'fixed' && fixed == null) ||
                    ((kind == 'fajr' || kind == 'maghrib') &&
                        !settings.isComplete)) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('সেভ করুন'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      await _mutate(() async {
        final resourceId = selectedIds.isEmpty ? null : selectedIds.first;
        final savedId = await _repository.saveAction(
          routineId: routineId,
          actionId: existing?['id'] as String?,
          title: title.text,
          notificationTitle: reminder.text,
          contentItemId: resourceId,
          scheduleKind: kind,
          offsetMinutes: offset,
          fixedTime: fixed == null
              ? null
              : "${fixed!.hour.toString().padLeft(2, '0')}:${fixed!.minute.toString().padLeft(2, '0')}:00",
          timezoneName: settings.location?.timezone,
          city: kind == 'fajr' || kind == 'maghrib'
              ? settings.location?.name
              : null,
          latitude: kind == 'fajr' || kind == 'maghrib'
              ? settings.location?.latitude
              : null,
          longitude: kind == 'fajr' || kind == 'maghrib'
              ? settings.location?.longitude
              : null,
          prayerMethod: kind == 'fajr' || kind == 'maghrib'
              ? settings.calculationMethod?.id
              : null,
        );
        await _repository.replaceActionResources(
          actionId: savedId,
          cmsIds: selectedIds,
        );
      });
    }
    title.dispose();
    reminder.dispose();
  }

  String _prayerPreview({
    required PrayerUtilitySettings settings,
    required String kind,
    required int offset,
  }) {
    try {
      final upcoming =
          PrayerRelativeReminder(
            anchor: kind == 'fajr'
                ? PrayerReminderAnchor.fajr
                : PrayerReminderAnchor.maghrib,
            minutesAfter: offset,
          ).nextOccurrence(
            calculator: ref.read(prayerCalculationServiceProvider),
            settings: settings,
            after: DateTime.now(),
          );
      return 'পরের নির্ধারিত সময়: ${TimeOfDay.fromDateTime(upcoming).format(context)}';
    } catch (_) {
      return 'নামাজের সময় এখন নির্ধারণ করা যাচ্ছে না।';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('আমার রুটিন'),
      actions: [
        IconButton(
          onPressed: _working ? null : _createRoutine,
          tooltip: 'নতুন রুটিন',
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
    body: FutureBuilder<_RoutinePageData>(
      future: _data,
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('রুটিন আনতে সমস্যা হয়েছে। আবার চেষ্টা করুন।'),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.resourceId != null)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.library_books_outlined),
                  title: Text('লাইব্রেরি থেকে রুটিনে যোগ করুন'),
                  subtitle: Text('নিচের রুটিনের + করণীয় চাপুন।'),
                ),
              ),
            if (data.routines.isEmpty)
              const ListTile(
                title: Text('এখনো রুটিন নেই'),
                subtitle: Text(
                  'উপরে + চাপুন এবং নিজের জন্য একটি রুটিন তৈরি করুন।',
                ),
              ),
            for (final routine in data.routines) ...[
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      title: Text(routine['title'].toString()),
                      subtitle: Text(
                        routine['is_active'] == true
                            ? 'চালু আছে'
                            : 'Pause করা আছে',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'pause') {
                            _mutate(
                              () => _repository.setRoutineActive(
                                routine['id'] as String,
                                routine['is_active'] != true,
                              ),
                            );
                          } else if (value == 'delete') {
                            _mutate(
                              () => _repository.deleteRoutine(
                                routine['id'] as String,
                              ),
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'pause',
                            child: Text(
                              routine['is_active'] == true ? 'Pause' : 'Resume',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                    for (final action in data.actions.where(
                      (item) => item['routine_id'] == routine['id'],
                    ))
                      ListTile(
                        onTap: () => context.push(
                          '/my-routines/action/${action['id']}',
                        ),
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(action['title'].toString()),
                        subtitle: Text(
                          "${action['schedule_kind']} · ${action['notification_title']}",
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editAction(
                                routineId: routine['id'] as String,
                                existing: action,
                              );
                            } else if (value == 'duplicate') {
                              _mutate(
                                () => _repository.duplicateAction(action),
                              );
                            } else if (value == 'done' || value == 'skipped') {
                              _mutate(
                                () => _repository.recordOutcome(
                                  actionId: action['id'] as String,
                                  localDate: DateTime.now(),
                                  outcome: value,
                                ),
                              );
                            } else if (value == 'delete') {
                              _mutate(
                                () => _repository.deleteAction(
                                  action['id'] as String,
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              enabled: false,
                              child: Text(
                                "আজ: ${data.outcomes[action['id']] ?? 'বাকি আছে'}",
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'done',
                              child: Text('Done'),
                            ),
                            const PopupMenuItem(
                              value: 'skipped',
                              child: Text('Skip'),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'duplicate',
                              child: Text('Duplicate'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: _working
                            ? null
                            : () => _editAction(
                                routineId: routine['id'] as String,
                              ),
                        icon: const Icon(Icons.add),
                        label: const Text('করণীয় যোগ করুন'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.push('/resources'),
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('রিসোর্স লাইব্রেরি খুলুন'),
            ),
          ],
        );
      },
    ),
  );
}

class _RoutinePageData {
  const _RoutinePageData({
    required this.routines,
    required this.actions,
    required this.outcomes,
  });
  final List<Map<String, dynamic>> routines;
  final List<Map<String, dynamic>> actions;
  final Map<String, String> outcomes;
}
