import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/progress/presentation/unified_progress_screen.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/personal_routines/data/personal_routine_repository.dart';
import 'package:sukun_life/features/personal_routines/data/personal_reminder_service.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/presentation/resource_picker_sheet.dart';
import 'package:sukun_life/features/personal_routines/domain/prayer_relative_reminder.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_routine_reminder_planner.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_action_resource_selection.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_routine_resource_prefill.dart';
import 'package:sukun_life/features/personal_routines/presentation/personal_surah_picker.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyRoutinesScreen extends ConsumerStatefulWidget {
  const MyRoutinesScreen({super.key, this.resourceId, this.initialTab});

  final String? resourceId;
  final String? initialTab;

  @override
  ConsumerState<MyRoutinesScreen> createState() => _MyRoutinesScreenState();
}

class _MyRoutinesScreenState extends ConsumerState<MyRoutinesScreen> {
  late Future<_RoutinePageData> _data;
  late Future<List<Map<String, dynamic>>> _templates;
  bool _working = false;
  bool _reminderEnabled = false;

  PersonalRoutineRepository get _repository =>
      PersonalRoutineRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _data = _load();
    _templates = _repository.listPublishedTemplates();
    unawaited(_readReminderEnabled());
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

  Future<void> _readReminderEnabled() async {
    try {
      final enabled = await ref
          .read(personalReminderServiceProvider)
          .isEnabled();
      if (mounted) setState(() => _reminderEnabled = enabled);
    } catch (_) {
      if (mounted) setState(() => _reminderEnabled = false);
    }
  }

  Future<void> _toggleReminders() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final service = ref.read(personalReminderServiceProvider);
      if (_reminderEnabled) {
        await service.disable();
        _notice('আপনার ব্যক্তিগত রুটিন রিমাইন্ডার বন্ধ হয়েছে।');
      } else {
        final granted = await service.enable();
        if (!granted) {
          _notice('রিমাইন্ডারের জন্য নোটিফিকেশন অনুমতি প্রয়োজন।');
        } else {
          _notice(
            kIsWeb ? 'রিমাইন্ডার চালু। ব্রাউজারে শুধু খোলা ট্যাবে কাজ করবে।' : 'রিমাইন্ডার চালু। নির্দিষ্ট সময়ে পেতে অ্যালার্মের অনুমতি ও ফোনের ব্যাটারি সেটিংস পরীক্ষা করুন।',
          );
        }
      }
      await _readReminderEnabled();
    } catch (_) {
      _notice('নোটিফিকেশন চালু করা যায়নি। আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _working = false);
    }
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
      try {
        await ref.read(personalReminderServiceProvider).refresh();
      } catch (_) {
        _notice('পরিবর্তন সংরক্ষিত হয়েছে, তবে রিমাইন্ডার আপডেট করা যায়নি।');
      }
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
    final selected = PersonalActionResourceSelection.fromLinks(
      existingLinks,
      legacyContentId: existing?['content_item_id'] as String?,
    );
    if (selected.length != existingLinks.length && existingLinks.isNotEmpty) {
      _notice('কিছু সংযুক্ত রেফারেন্স এখন সম্পাদনা করা যাচ্ছে না।');
      title.dispose();
      reminder.dispose();
      return;
    }
    if (prefill != null &&
        !selected.any((item) => item.contentItemId == prefill!.contentId)) {
      selected.add(PersonalActionResourceSelection.cms(prefill.contentId));
    }
    final resourceRows = await Supabase.instance.client
        .from('content_items')
        .select(
          'id,slug,title,title_bn,type,status,visibility,verification_status,media_source_type,media_url,category_id',
        )
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
                  for (var index = 0; index < selected.length; index++)
                    Builder(
                      builder: (context) {
                        final selectedItem = selected[index];
                        final id = selectedItem.contentItemId;
                        final resource = resources
                            .where((item) => item.id == id)
                            .firstOrNull;
                        return ListTile(
                          dense: true,
                          title: Text(
                            selectedItem.provider == 'quran'
                                ? 'সূরা ${selectedItem.surahNumber}'
                                : resource?.displayTitle ?? 'রিসোর্স অনুপলব্ধ',
                          ),
                          subtitle: Text(
                            selectedItem.provider == 'quran'
                                ? 'কুরআন রিডারে খুলবে'
                                : resource?.type ?? 'অনুপলব্ধ',
                          ),
                          leading: Icon(
                            selectedItem.provider == 'quran'
                                ? Icons.menu_book_outlined
                                : Icons.library_books_outlined,
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_upward_rounded),
                                tooltip: 'উপরে নিন',
                                onPressed: index == 0
                                    ? null
                                    : () => update(() {
                                        final moved = selected.removeAt(index);
                                        selected.insert(index - 1, moved);
                                      }),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_downward_rounded),
                                tooltip: 'নিচে নিন',
                                onPressed: index == selected.length - 1
                                    ? null
                                    : () => update(() {
                                        final moved = selected.removeAt(index);
                                        selected.insert(index + 1, moved);
                                      }),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                tooltip: 'বাদ দিন',
                                onPressed: () =>
                                    update(() => selected.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  OutlinedButton.icon(
                    onPressed: selected.length >= 16
                        ? null
                        : () async {
                            final id = await showResourcePickerSheet(
                              context: ctx,
                              resources: resources
                                  .where(
                                    (item) => !selected.any(
                                      (selectedItem) =>
                                          selectedItem.contentItemId == item.id,
                                    ),
                                  )
                                  .toList(growable: false),
                              selectedId: '',
                            );
                            if (id != null &&
                                id.isNotEmpty &&
                                !selected.any(
                                  (item) => item.contentItemId == id,
                                ) &&
                                ctx.mounted) {
                              update(
                                () => selected.add(
                                  PersonalActionResourceSelection.cms(id),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('লাইব্রেরি থেকে রিসোর্স বাছুন'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: selected.length >= 16
                        ? null
                        : () async {
                            final number = await showPersonalSurahPicker(
                              context: ctx,
                              exclude: selected
                                  .where((item) => item.provider == 'quran')
                                  .map((item) => item.surahNumber!)
                                  .toSet(),
                            );
                            if (number != null &&
                                !selected.any(
                                  (item) => item.surahNumber == number,
                                ) &&
                                ctx.mounted) {
                              update(
                                () => selected.add(
                                  PersonalActionResourceSelection.quran(number),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('কুরআন থেকে সূরা বাছুন'),
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
                  if (kind == 'fixed' && fixed != null)
                    Builder(
                      builder: (context) {
                        final now = DateTime.now();
                        final next = nextPersonalFixedOccurrence(
                          now,
                          hour: fixed!.hour,
                          minute: fixed!.minute,
                        );
                        final when = DateUtils.isSameDay(now, next)
                            ? 'আজ'
                            : 'আগামীকাল';
                        return Text(
                          'পরবর্তী রিমাইন্ডার: $when ${fixed!.format(context)}। '
                          'রিমাইন্ডার চালু ও অনুমোদিত থাকলে নোটিফিকেশন আসবে।',
                          style: const TextStyle(fontSize: 12),
                        );
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
                    'সময় সংরক্ষিত হবে। ব্রাউজার বন্ধ থাকলে রিমাইন্ডার নাও আসতে পারে।',
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
      var saved = false;
      await _mutate(() async {
        final resourceId = selected
            .where((item) => item.provider == 'cms')
            .firstOrNull
            ?.contentItemId;
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
          orderedResources: selected,
        );
        saved = true;
      });
      // Saving a time does not grant notification permission or opt the user
      // in. Explain the additional step instead of promising delivery.
      if (saved &&
          kind != 'manual' &&
          !await ref.read(personalReminderServiceProvider).isEnabled()) {
        _notice(
          'সময় সংরক্ষিত হয়েছে। নোটিফিকেশন পেতে রুটিন পেজের ঘণ্টা আইকন থেকে রিমাইন্ডার চালু করুন।',
        );
      }
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
      title: const Text('রুটিন'),
      actions: [
        IconButton(
          onPressed: _working ? null : _toggleReminders,
          tooltip: _reminderEnabled
              ? 'ব্যক্তিগত রিমাইন্ডার বন্ধ করুন'
              : 'ব্যক্তিগত রিমাইন্ডার চালু করুন',
          icon: Icon(
            _reminderEnabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
          ),
        ),
        IconButton(
          onPressed: _working ? null : _createRoutine,
          tooltip: 'নতুন রুটিন',
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
    body: DefaultTabController(
      length: 3,
      initialIndex: widget.resourceId != null
          ? 0
          : widget.initialTab == 'progress'
          ? 2
          : widget.initialTab == 'assigned'
          ? 1
          : 0,
      child: Column(
        children: [
          const TabBar(
            key: Key('routine-hub-tabs'),
            tabs: [
              Tab(text: 'আমার রুটিন'),
              Tab(text: 'নির্ধারিত'),
              Tab(text: 'অগ্রগতি'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                FutureBuilder<_RoutinePageData>(
                  future: _data,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      if (snap.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'রুটিন আনতে সমস্যা হয়েছে। আবার চেষ্টা করুন।',
                              ),
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FilledButton.icon(
                            onPressed: _working ? null : _createRoutine,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('নতুন রুটিন তৈরি করুন'),
                          ),
                        ),
                        if (data.routines.isEmpty)
                          const ListTile(
                            title: Text('এখনো রুটিন নেই'),
                            subtitle: Text(
                              'নতুন রুটিন তৈরি করে করণীয় যোগ করুন।',
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
                                          routine['is_active'] == true
                                              ? 'Pause'
                                              : 'Resume',
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
                                    leading: const Icon(
                                      Icons.check_circle_outline,
                                    ),
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
                                            () => _repository.duplicateAction(
                                              action,
                                            ),
                                          );
                                        } else if (value == 'done' ||
                                            value == 'skipped') {
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
                _assignedPlanTab(),
                const UnifiedProgressScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _assignedPlanTab() {
    final isPatient = ref.watch(appSessionProvider).value?.isPatient == true;
    return ListView(
      key: const Key('routine-assigned-tab'),
      padding: const EdgeInsets.all(16),
      children: [
        if (isPatient) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_turned_in_outlined),
              title: const Text('সেশন থেকে নির্ধারিত রুটিন'),
              subtitle: const Text('আপনার অনুমোদিত পরিকল্পনা'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/patient/plan'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.today_outlined),
              title: const Text('আজকের নির্ধারিত আমল'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/patient/today'),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Text(
            'প্রস্তুত রুটিন',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _templates,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const ListTile(
                title: Text('রুটিনগুলো এখন দেখানো যাচ্ছে না'),
              );
            }
            final templates = snapshot.data ?? const [];
            if (templates.isEmpty) {
              return const ListTile(
                title: Text('এখনো কোনো প্রস্তুত রুটিন নেই'),
              );
            }
            return Column(
              children: [
                for (final template in templates)
                  Card(
                    key: Key('routine-template-${template['id']}'),
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: Text(template['title'].toString()),
                      subtitle: Text(
                        '${(template['routine_template_steps'] as List?)?.length ?? 0}টি আমল',
                      ),
                      trailing: TextButton(
                        onPressed: _working
                            ? null
                            : () => _mutate(() async {
                                await _repository.adoptPublishedTemplate(
                                  template['id'] as String,
                                );
                                _notice('রুটিনটি আমার রুটিনে যোগ হয়েছে।');
                              }),
                        child: const Text('রুটিনে যোগ করুন'),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
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
