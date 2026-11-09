import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/core/widgets/reader_settings_sheet.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/media_library/presentation/audio_library_actions.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/personal_routines/presentation/personal_surah_picker.dart';
import 'package:sukun_life/features/personal_routines/data/personal_routine_repository.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_notification_destination.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Same action detail screen for members and patients' *self-owned* routines.
/// Supabase RLS independently protects action and linked-resource ownership.
class PersonalActionDetailScreen extends StatefulWidget {
  const PersonalActionDetailScreen({
    super.key,
    required this.actionId,
    this.fromReminder = false,
  });
  final String actionId;
  final bool fromReminder;

  @override
  State<PersonalActionDetailScreen> createState() =>
      _PersonalActionDetailScreenState();
}

class _PersonalActionDetailScreenState
    extends State<PersonalActionDetailScreen> {
  late Future<_PersonalActionDetail> _load;
  bool _saving = false;

  PersonalRoutineRepository get _repo =>
      PersonalRoutineRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load = _read();
    if (widget.fromReminder) unawaited(_openReminderDestination());
  }

  Future<void> _openReminderDestination() async {
    try {
      final data = await _load;
      if (!mounted || data.action == null) return;
      // Read/RLS authorizes the target before navigation. No URL from a
      // notification is ever followed directly.
      final route = personalNotificationDestination(data.references);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(route);
      });
    } catch (_) {
      // A failed owner-scoped read remains on the ordinary error/retry screen.
    }
  }

  Future<_PersonalActionDetail> _read() async {
    final action = await _repo.getAction(widget.actionId);
    if (action == null) return const _PersonalActionDetail();
    final refs = await _repo.listActionResources(widget.actionId);
    // Backward compatibility for actions created before multiple links.
    if (refs.isEmpty && action['content_item_id'] is String) {
      final id = action['content_item_id'] as String;
      final item = await Supabase.instance.client
          .from('content_items')
          .select('id,title,title_bn,type,status,visibility')
          .eq('id', id)
          .maybeSingle();
      if (item != null) {
        refs.add({
          'provider': 'cms',
          'content_item_id': id,
          'content_items': item,
        });
      }
    }
    final outcomes = await _repo.todaysOutcomes(DateTime.now());
    return _PersonalActionDetail(
      action: action,
      references: refs,
      todayOutcome: outcomes[widget.actionId],
    );
  }

  Future<void> _complete(String status) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repo.recordOutcome(
        actionId: widget.actionId,
        localDate: DateTime.now(),
        outcome: status,
      );
      if (!mounted) return;
      setState(() => _load = _read());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'done'
                ? 'আজকের আমল সম্পন্ন'
                : 'আজকের আমল বাদ দেওয়া হয়েছে',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সংরক্ষণ হয়নি। আবার চেষ্টা করুন।')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('আমার করণীয়'),
      actions: const [ReaderSettingsAction()],
    ),
    bottomNavigationBar: FutureBuilder<_PersonalActionDetail>(
      future: _load,
      builder: (context, snapshot) => snapshot.data?.action == null
          ? const SizedBox.shrink()
          : SukunBottomActionBar(
              children: [
                OutlinedButton(
                  key: const Key('personal-action-skip'),
                  onPressed: _saving ? null : () => _complete('skipped'),
                  child: const Text('আজ বাদ দিন'),
                ),
                FilledButton.icon(
                  key: const Key('personal-action-done'),
                  onPressed: _saving ? null : () => _complete('done'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('আজকের আমল সম্পন্ন'),
                  ),
                ),
              ],
            ),
    ),
    body: FutureBuilder<_PersonalActionDetail>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'রিসোর্স আনা যায়নি। আবার চেষ্টা করুন।',
            onRetry: () => setState(() => _load = _read()),
          );
        }
        if (!snapshot.hasData) {
          return const AppLoadingState(label: 'করণীয় আনা হচ্ছে…');
        }
        final data = snapshot.data!;
        if (data.action == null) {
          return const AppEmptyState(
            title: 'অ্যাকশনটি পাওয়া যায়নি বা অনুমতি নেই।',
            message: 'রুটিন পাতা থেকে আবার খুলে দেখুন।',
          );
        }
        final action = data.action!;
        final textTheme = Theme.of(context).textTheme;
        final reminder = (action['notification_title'] as String? ?? '').trim();
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            SukunSpace.page,
            SukunSpace.xs,
            SukunSpace.page,
            SukunSpace.section,
          ),
          children: [
            Text(
              action['title'] as String? ?? 'আমার করণীয়',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (reminder.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                reminder,
                style: textTheme.bodyLarge?.copyWith(color: SukunColors.muted),
              ),
            ],
            if (data.todayOutcome case final outcome?) ...[
              const SizedBox(height: SukunSpace.md),
              Align(
                alignment: Alignment.centerLeft,
                child: SukunStatusPill(
                  label: outcome == 'done'
                      ? 'আজকের অবস্থা: সম্পন্ন'
                      : 'আজকের অবস্থা: বাদ দেওয়া হয়েছে',
                  tone: outcome == 'done'
                      ? SukunStatusTone.success
                      : SukunStatusTone.neutral,
                ),
              ),
            ],
            if ((action['notes'] as String? ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: SukunSpace.lg),
              SukunSurface(
                tone: SukunSurfaceTone.soft,
                showBorder: false,
                child: SelectableText(
                  action['notes'] as String,
                  key: const Key('personal-action-reviewed-instructions'),
                  style: textTheme.bodyLarge,
                ),
              ),
            ],
            const SizedBox(height: SukunSpace.section),
            const SukunSectionHeader(title: 'সংযুক্ত রিসোর্স'),
            const SizedBox(height: SukunSpace.sm),
            if (data.references.isEmpty)
              const SukunSurface(
                tone: SukunSurfaceTone.soft,
                showBorder: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'এখনো কোনো রিসোর্স যুক্ত করা হয়নি',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'রুটিন থেকে "সম্পাদনা" চেপে লাইব্রেরির রিসোর্স যুক্ত করুন।',
                    ),
                  ],
                ),
              ),
            for (final reference in data.references)
              _ResourceReferenceTile(reference: reference),
          ],
        );
      },
    ),
  );
}

class _ResourceReferenceTile extends StatelessWidget {
  const _ResourceReferenceTile({required this.reference});
  final Map<String, dynamic> reference;

  @override
  Widget build(BuildContext context) {
    final provider = reference['provider'] as String?;
    final content = reference['content_items'];
    final cms = content is Map ? Map<String, dynamic>.from(content) : null;
    final id = reference['content_item_id'] as String?;
    final canOpen =
        provider == 'cms' &&
        cms != null &&
        cms['status'] == 'published' &&
        cms['visibility'] == 'public' &&
        id != null;
    final label = cms?['title_bn'] as String?;
    final name = label?.trim().isNotEmpty == true
        ? label!
        : (cms?['title'] as String? ?? 'রিসোর্সটি এখন অনুপলব্ধ');
    final external = reference['external_resource_ref'] as String?;
    final surahNumber = provider == 'quran'
        ? quranNumberFromRef(external)
        : null;
    final ayahNumber = provider == 'quran'
        ? quranAyahNumberFromRef(external)
        : null;
    final route = canOpen
        ? '/resources/${Uri.encodeComponent(id)}'
        : surahNumber != null
        ? '/resources/quran/$surahNumber${ayahNumber == null ? '' : '?ayah=$ayahNumber'}'
        : null;
    final audioResource = canOpen && cms['type'] == 'audio'
        ? LinkedResource(
            id: id,
            title: cms['title'] as String? ?? name,
            titleBn: cms['title_bn'] as String?,
            type: 'audio',
            mediaSourceType: cms['media_source_type'] as String?,
            mediaUrl: cms['media_url'] as String?,
          )
        : null;
    Widget? trailing = route != null ? const Icon(Icons.chevron_right) : null;
    if (audioResource != null && AudioLibraryActions.supports(audioResource)) {
      trailing = AudioLibraryActions(resource: audioResource, compact: true);
    }
    return Card(
      child: ListTile(
        leading: Icon(
          provider == 'quran'
              ? Icons.menu_book_outlined
              : Icons.library_books_outlined,
        ),
        title: Text(
          provider == 'cms'
              ? name
              : surahNumber != null
              ? ayahNumber == null
                    ? 'সূরা $surahNumber'
                    : 'সূরা $surahNumber · আয়াত $ayahNumber'
              : 'রিসোর্স অনুপলব্ধ',
        ),
        subtitle: Text(
          route != null ? 'খুলুন ও আমল করুন' : 'যাচাই বা প্রকাশের অপেক্ষায়',
        ),
        trailing: trailing,
        onTap: route == null ? null : () => context.push(route),
      ),
    );
  }
}

class _PersonalActionDetail {
  const _PersonalActionDetail({
    this.action,
    this.references = const [],
    this.todayOutcome,
  });
  final Map<String, dynamic>? action;
  final List<Map<String, dynamic>> references;
  final String? todayOutcome;
}
