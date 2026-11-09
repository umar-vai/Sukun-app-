import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/personal_routines/presentation/routine_hub_parts.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/features/progress/presentation/unified_progress_screen.dart';
import 'package:sukun_life/features/personal_routines/presentation/today_routine_panel.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/personal_routines/data/personal_routine_repository.dart';
import 'package:sukun_life/features/personal_routines/data/personal_reminder_service.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/presentation/bulk_template_import_screen.dart';
import 'package:sukun_life/features/care_plans/presentation/resource_picker_sheet.dart';
import 'package:sukun_life/features/personal_routines/domain/prayer_relative_reminder.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_routine_reminder_planner.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_action_resource_selection.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_routine_resource_prefill.dart';
import 'package:sukun_life/features/personal_routines/presentation/personal_surah_picker.dart';
import 'package:sukun_life/features/personal_routines/presentation/routine_quran_reference_picker.dart';
import 'package:sukun_life/features/resources/presentation/canonical_quran_ayah_picker.dart';
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
  late RoutineHubTab _tab = routineHubInitialTab(
    initialTab: widget.initialTab,
    resourceId: widget.resourceId,
  );
  final _readyKey = GlobalKey();

  PersonalRoutineRepository get _repository =>
      PersonalRoutineRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _refresh();
    if (widget.initialTab == 'assigned' && widget.resourceId == null) {
      // Old links to the "assigned" tab scroll to ready-made routines.
      _scrollToReadyRoutines();
    }
  }

  Future<void> _scrollToReadyRoutines() async {
    try {
      await _data;
    } catch (_) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _readyKey.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
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

  /// Pick many library items (duas, audio, surahs) at once and get daily
  /// reminders for all of them in a new routine.
  Future<void> _bulkResourceReminders() async {
    if (_working) return;
    final resources = ref
        .read(carePlansRepositoryProvider)
        .getAvailableResources()
        .then(
          (all) => all
              .where((r) => r.isLinkable && r.visibility == 'public')
              .toList(growable: false),
        );
    final items = await showBulkTemplateImport(
      context,
      recipientLabel: 'আমার রিমাইন্ডার',
      resources: resources,
      showTemplates: false,
      showDuration: false,
      confirmLabel: 'রিমাইন্ডার চালু করুন',
    );
    if (items == null || items.isEmpty || !mounted) return;
    var saved = false;
    await _mutate(() async {
      final settings = await ref.read(utilityPreferencesStoreProvider).load();
      final routine = await _repository.createRoutine('উপকরণের রিমাইন্ডার');
      final routineId = routine['id'] as String;
      for (final draft in expandBulkItems(items)) {
        final links = [
          for (final id in draft.resourceIds)
            if (id.startsWith('quran:'))
              PersonalActionResourceSelection.quran(int.parse(id.substring(6)))
            else
              PersonalActionResourceSelection.cms(id),
        ];
        final actionId = await _repository.saveAction(
          routineId: routineId,
          title: draft.title,
          notificationTitle: draft.title,
          contentItemId: draft.cmsResourceIds.firstOrNull,
          scheduleKind: 'fixed',
          offsetMinutes: 10,
          fixedTime: draft.time.databaseValue,
          timezoneName: settings.location?.timezone,
        );
        if (links.isNotEmpty) {
          await _repository.replaceActionResources(
            actionId: actionId,
            orderedResources: links,
          );
        }
      }
      saved = true;
    });
    if (!saved || !mounted) return;
    if (_reminderEnabled) {
      _notice(
        '${toBanglaDigits('${items.length}')}টি উপকরণের রিমাইন্ডার চালু হয়েছে।',
      );
    } else {
      // The user started this, so it is the right moment to ask for
      // notification permission instead of sending them to the bell icon.
      await _toggleReminders();
    }
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
        _notice('এই পাঠটি রুটিনে যুক্ত করা যাচ্ছে না।');
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
          'id,slug,title,title_bn,type,status,visibility,verification_status,'
          'media_source_type,media_url,category_id,surah_number,ayah_number,'
          'ayah_end_number,content_categories(id,name,name_bn,slug,sort_order)',
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

    String? formError;
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
                  if (formError != null)
                    Container(
                      key: const Key('routine-action-form-error'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SukunColors.errorSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        formError!,
                        style: const TextStyle(color: SukunColors.error),
                      ),
                    ),
                  if (prefill != null)
                    ListTile(
                      leading: const Icon(Icons.library_books_outlined),
                      title: Text(prefill.actionTitle),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'সংযুক্ত পাঠ ও অডিও (সর্বোচ্চ ১৬টি)',
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
                                ? selectedItem.ayahNumber == null
                                      ? 'সূরা ${selectedItem.surahNumber}'
                                      : 'সূরা ${selectedItem.surahNumber} · আয়াত ${selectedItem.ayahNumber}'
                                : resource?.displayTitle ??
                                      'পাঠটি এখন পাওয়া যাচ্ছে না',
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
                              onPickCanonicalQuran:
                                  (pickerContext, wholeSurah) =>
                                      pickRoutineQuranReference(
                                        pickerContext,
                                        wholeSurah,
                                        selectedReferences: selected
                                            .where(
                                              (item) =>
                                                  item.provider == 'quran',
                                            )
                                            .map((item) => item.key)
                                            .toSet(),
                                      ),
                            );
                            if (id == null || id.isEmpty || !ctx.mounted) {
                              return;
                            }
                            final selection = id.startsWith('quran:')
                                ? PersonalActionResourceSelection.fromLinks([
                                    {
                                      'provider': 'quran',
                                      'external_resource_ref': id,
                                    },
                                  ]).firstOrNull
                                : PersonalActionResourceSelection.cms(id);
                            if (selection != null &&
                                !selected.any(
                                  (item) => item.key == selection.key,
                                )) {
                              update(() => selected.add(selection));
                            }
                          },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('লাইব্রেরি, সূরা বা আয়াত বাছুন'),
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
                    label: const Text('কুরআন থেকে সম্পূর্ণ সূরা বাছুন'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: selected.length >= 16
                        ? null
                        : () async {
                            final choice = await showCanonicalQuranAyahPicker(
                              context: ctx,
                              excludedReferences: selected
                                  .where((item) => item.provider == 'quran')
                                  .map((item) => item.key)
                                  .toSet(),
                            );
                            if (choice != null &&
                                ctx.mounted &&
                                !selected.any(
                                  (item) => item.key == choice.reference,
                                )) {
                              update(
                                () => selected.add(
                                  PersonalActionResourceSelection.quranAyah(
                                    choice.surahNumber,
                                    choice.ayahNumber,
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.format_list_numbered_rounded),
                    label: const Text('কুরআনের নির্দিষ্ট আয়াত বাছুন'),
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
                // Same rules as before, but say what is missing instead of
                // silently ignoring the tap.
                final String? problem = title.text.trim().isEmpty
                    ? 'করণীয়ের নাম লিখুন।'
                    : reminder.text.trim().isEmpty
                    ? 'নোটিফিকেশনের শিরোনাম লিখুন।'
                    : (kind == 'fixed' && fixed == null)
                    ? 'নির্দিষ্ট সময় বেছে নিন।'
                    : ((kind == 'fajr' || kind == 'maghrib') &&
                          !settings.isComplete)
                    ? 'আগে নামাজের সময়ের সেটিংসে শহর ও পদ্ধতি নির্বাচন করুন।'
                    : null;
                if (problem != null) {
                  update(() => formError = problem);
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

  Future<void> _deleteRoutine(Map<String, dynamic> routine) async {
    final confirmed = await confirmRoutineDeletion(
      context,
      title: routine['title'].toString(),
      isRoutine: true,
    );
    if (!confirmed) return;
    await _mutate(() => _repository.deleteRoutine(routine['id'] as String));
  }

  Future<void> _onActionMenu(
    Map<String, dynamic> routine,
    Map<String, dynamic> action,
    String value,
  ) async {
    switch (value) {
      case 'edit':
        await _editAction(routineId: routine['id'] as String, existing: action);
      case 'duplicate':
        await _mutate(() => _repository.duplicateAction(action));
      case 'done' || 'skipped':
        await _mutate(
          () => _repository.recordOutcome(
            actionId: action['id'] as String,
            localDate: DateTime.now(),
            outcome: value,
          ),
        );
      case 'delete':
        final confirmed = await confirmRoutineDeletion(
          context,
          title: action['title'].toString(),
          isRoutine: false,
        );
        if (!confirmed) return;
        await _mutate(() => _repository.deleteAction(action['id'] as String));
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
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SukunSpace.page,
                SukunSpace.xs,
                SukunSpace.page,
                SukunSpace.md,
              ),
              child: RoutineHubTabs(
                key: const Key('routine-hub-tabs'),
                selected: _tab,
                onSelected: (tab) => setState(() => _tab = tab),
              ),
            ),
            Expanded(
              child: switch (_tab) {
                RoutineHubTab.today => _todayTab(),
                RoutineHubTab.myRoutines => _myRoutinesTab(),
                RoutineHubTab.progress => const UnifiedProgressScreen(
                  embedded: true,
                ),
              },
            ),
          ],
        ),
      ),
    ),
  );

  Widget _todayTab() => FutureBuilder<_RoutinePageData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return AppErrorState(
          message: 'আজকের রুটিন আনা যায়নি। আবার চেষ্টা করুন।',
          onRetry: _refresh,
        );
      }
      final data = snapshot.data;
      if (data == null) {
        return const AppLoadingState(label: 'আজকের রুটিন আনা হচ্ছে…');
      }
      return TodayRoutinePanel(
        routines: data.routines,
        actions: data.actions,
        outcomes: data.outcomes,
        busy: _working,
        onToggleDone: (actionId, currentlyDone) {
          _mutate(
            () => currentlyDone
                ? _repository.clearOutcome(
                    actionId: actionId,
                    localDate: DateTime.now(),
                  )
                : _repository.recordOutcome(
                    actionId: actionId,
                    localDate: DateTime.now(),
                    outcome: 'done',
                  ),
          );
        },
        onOpen: (id) =>
            context.push('/my-routines/action/${Uri.encodeComponent(id)}'),
        onOpenPatientToday:
            ref.watch(appSessionProvider).value?.isPatient == true
            ? () => context.push('/patient/today')
            : null,
        onOpenHistory: () => setState(() => _tab = RoutineHubTab.progress),
      );
    },
  );

  Widget _myRoutinesTab() => FutureBuilder<_RoutinePageData>(
    future: _data,
    builder: (context, snap) {
      if (!snap.hasData) {
        if (snap.hasError) {
          return AppErrorState(
            message: 'রুটিন আনতে সমস্যা হয়েছে। আবার চেষ্টা করুন।',
            onRetry: _refresh,
          );
        }
        return const AppLoadingState(label: 'রুটিন আনা হচ্ছে…');
      }
      final data = snap.data!;
      final isPatient = ref.watch(appSessionProvider).value?.isPatient == true;
      return ListView(
        key: const Key('routine-mine-list'),
        padding: const EdgeInsets.fromLTRB(
          SukunSpace.page,
          SukunSpace.xs,
          SukunSpace.page,
          SukunSpace.sectionLarge,
        ),
        children: [
          if (widget.resourceId != null) ...[
            const SukunSurface(
              tone: SukunSurfaceTone.soft,
              showBorder: false,
              child: Row(
                children: [
                  Icon(Icons.library_books_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'লাইব্রেরি থেকে রুটিনে যোগ করুন',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text('নিচের রুটিনের + করণীয় চাপুন।'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SukunSpace.md),
          ],
          if (isPatient) ...[
            SukunSurface(
              key: const Key('routine-patient-plan-link'),
              tone: SukunSurfaceTone.soft,
              showBorder: false,
              onTap: () => context.push('/patient/plan'),
              child: const Row(
                children: [
                  Icon(Icons.assignment_turned_in_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'সেশন থেকে নির্ধারিত রুটিন',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text('আপনার অনুমোদিত পরিকল্পনা'),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: SukunSpace.md),
          ],
          FilledButton.icon(
            key: const Key('routine-bulk-resource-reminders'),
            onPressed: _working ? null : _bulkResourceReminders,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('উপকরণ থেকে রিমাইন্ডার চালু করুন'),
          ),
          const SizedBox(height: SukunSpace.sm),
          OutlinedButton.icon(
            onPressed: _working ? null : _createRoutine,
            icon: const Icon(Icons.add_rounded),
            label: const Text('নতুন রুটিন তৈরি করুন'),
          ),
          const SizedBox(height: SukunSpace.lg),
          if (data.routines.isEmpty)
            const SukunSurface(
              tone: SukunSurfaceTone.soft,
              showBorder: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'এখনো রুটিন নেই',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text('নতুন রুটিন তৈরি করে করণীয় যোগ করুন।'),
                ],
              ),
            ),
          for (final routine in data.routines) ...[
            RoutineCard(
              routine: routine,
              actions: data.actions
                  .where((item) => item['routine_id'] == routine['id'])
                  .toList(growable: false),
              outcomes: data.outcomes,
              busy: _working,
              onToggleActive: () => _mutate(
                () => _repository.setRoutineActive(
                  routine['id'] as String,
                  routine['is_active'] != true,
                ),
              ),
              onDeleteRoutine: () => _deleteRoutine(routine),
              onOpenAction: (action) =>
                  context.push('/my-routines/action/${action['id']}'),
              onActionMenu: (action, value) =>
                  _onActionMenu(routine, action, value),
              onAddAction: () =>
                  _editAction(routineId: routine['id'] as String),
            ),
            const SizedBox(height: SukunSpace.md),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/resources'),
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('পাঠ ও অডিও খুলুন'),
            ),
          ),
          const SizedBox(height: SukunSpace.section),
          _readyRoutinesSection(),
        ],
      );
    },
  );

  /// Published ready-made routines (the old "নির্ধারিত" tab). Kept under My
  /// Routines; `?tab=assigned` scrolls here.
  Widget _readyRoutinesSection() => Column(
    key: _readyKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SukunSectionHeader(
        key: Key('routine-assigned-tab'),
        title: 'প্রস্তুত রুটিন',
        subtitle: 'এক চাপে নিজের রুটিনে যোগ করুন',
      ),
      const SizedBox(height: SukunSpace.md),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _templates,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(SukunSpace.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const Text('রুটিনগুলো এখন দেখানো যাচ্ছে না');
          }
          final templates = snapshot.data ?? const [];
          if (templates.isEmpty) {
            return const Text('এখনো কোনো প্রস্তুত রুটিন নেই');
          }
          return Column(
            children: [
              for (final template in templates) ...[
                SukunSurface(
                  key: Key('routine-template-${template['id']}'),
                  padding: const EdgeInsets.all(SukunSpace.lg),
                  child: Row(
                    children: [
                      const SukunIconBadge(icon: Icons.auto_awesome_outlined),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template['title'].toString(),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${(template['routine_template_steps'] as List?)?.length ?? 0}টি আমল',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: SukunColors.muted),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
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
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    ],
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
