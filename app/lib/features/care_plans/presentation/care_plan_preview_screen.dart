import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';

class CarePlanPreviewScreen extends ConsumerStatefulWidget {
  const CarePlanPreviewScreen({
    super.key,
    required this.patientId,
    required this.planId,
  });

  final String patientId;
  final String planId;

  @override
  ConsumerState<CarePlanPreviewScreen> createState() =>
      _CarePlanPreviewScreenState();
}

class _CarePlanPreviewScreenState extends ConsumerState<CarePlanPreviewScreen> {
  late Future<(CarePlan, List<PlanAction>)> _preview;

  @override
  void initState() {
    super.initState();
    _preview = _load();
  }

  Future<(CarePlan, List<PlanAction>)> _load() async {
    final repository = ref.read(carePlansRepositoryProvider);
    final results = await Future.wait<Object?>([
      repository.getPlan(widget.planId),
      repository.getActions(widget.planId),
    ]);
    final plan = results[0] as CarePlan?;
    if (plan == null || plan.patientId != widget.patientId) {
      throw const CarePlanWorkflowException('Care plan was not found.');
    }
    final actions = (results[1] as List<PlanAction>)
        .where((action) => action.reviewStatus == ActionReviewStatus.approved)
        .toList(growable: false);
    return (plan, actions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('রোগী যেমন দেখবেন')),
      bottomNavigationBar: SukunBottomActionBar(
        children: [
          OutlinedButton.icon(
            key: const Key('preview-back-to-plan'),
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('প্ল্যানে ফিরে যান'),
          ),
        ],
      ),
      backgroundColor: SukunColors.mist,
      body: FutureBuilder<(CarePlan, List<PlanAction>)>(
        future: _preview,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'প্রিভিউ তৈরি হচ্ছে…');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'তথ্য আনা যাচ্ছে না। আবার চেষ্টা করুন।',
            );
          }
          final (plan, actions) = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            children: [
              const SukunStepper(current: 2),
              const SizedBox(height: SukunSpace.page),
              if (plan.status == CarePlanStatus.draft) ...[
                const SukunSurface(
                  tone: SukunSurfaceTone.warning,
                  showBorder: false,
                  child: Row(
                    children: [
                      SukunIconBadge(icon: Icons.visibility_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'শুধু প্রিভিউ। যাচাই ও চালু না করা পর্যন্ত রোগী এই খসড়া দেখবেন না।',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              SukunPageIntro(
                eyebrow: 'রোগীর প্রিভিউ',
                title: 'আপনার সেবা পরিকল্পনা',
                subtitle: '${plan.name} · শুরু ${_formatDate(plan.startDate)}',
                trailing: const SukunIconBadge(
                  icon: Icons.assignment_turned_in_outlined,
                  size: 54,
                ),
              ),
              const SizedBox(height: 24),
              const SukunSectionHeader(
                title: 'আজকের করণীয়',
                subtitle: 'শুধু অনুমোদিত করণীয় রোগী দেখতে পান।',
              ),
              const SizedBox(height: 12),
              if (actions.isEmpty)
                const SukunSurface(
                  tone: SukunSurfaceTone.soft,
                  showBorder: false,
                  child: Text('এই প্রিভিউতে এখনো কোনো অনুমোদিত করণীয় নেই।'),
                )
              else
                for (final action in actions) ...[
                  _PatientActionCard(action: action),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _PatientActionCard extends StatelessWidget {
  const _PatientActionCard({required this.action});

  final PlanAction action;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SukunIconBadge(icon: Icons.check_circle_outline),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_frequencyLabelBn(action.frequency)} · ${_timingLabel(action, context)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action.instruction?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(action.instruction!),
          ],
          if (action.countTarget != null || action.durationMinutes != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                if (action.countTarget != null)
                  SukunStatusPill(label: '${action.countTarget} বার'),
                if (action.durationMinutes != null)
                  SukunStatusPill(label: '${action.durationMinutes} মিনিট'),
              ],
            ),
          ],
          if (action.linkedResources.isNotEmpty) ...[
            const Divider(height: 28),
            for (final resource in action.linkedResources) ...[
              Row(
                children: [
                  const Icon(Icons.library_books_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(resource.titleBn ?? resource.title)),
                ],
              ),
              if (resource.usageNote?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Text(resource.usageNote!),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

String _timingLabel(PlanAction action, BuildContext context) {
  if (action.exactTime != null) {
    return TimeOfDay.fromDateTime(action.exactTime!).format(context);
  }
  final value = action.timeWindow;
  if (value == null || value.isEmpty) return 'সময় নির্ধারিত নেই';
  return switch (value) {
    'morning' => 'সকাল',
    'afternoon' => 'দুপুর',
    'evening' => 'সন্ধ্যা',
    'night' => 'রাত',
    'anytime' => 'যেকোনো সময়',
    _ => value,
  };
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _frequencyLabelBn(ActionFrequency frequency) {
  if (frequency.type == ActionFrequencyType.dates) {
    final kind = frequency.ghusl?.label;
    return '${kind == null ? '' : '$kind · '}${frequency.dates.length}টি তারিখ';
  }
  if (frequency.type == ActionFrequencyType.daily) {
    return frequency.interval == 1
        ? 'প্রতিদিন'
        : 'প্রতি ${frequency.interval} দিন পর';
  }
  const days = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহস্পতি', 'শুক্র', 'শনি', 'রবি'];
  final selected = frequency.weekdays.toList()..sort();
  return selected.map((day) => days[day - 1]).join(', ');
}
