import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_typography.dart';
import 'package:sukun_life/core/widgets/async_states.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/resources/data/resources_providers.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';
import 'package:sukun_life/features/resources/domain/ruqyah_audio_topics.dart';
import 'package:sukun_life/features/self_assessment/data/self_assessment_repository.dart';
import 'package:sukun_life/features/self_assessment/domain/self_assessment.dart';

const selfDiagnosisPath = '/resources/self-diagnosis';

String _bnDigits(int value) {
  const digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  return value
      .toString()
      .split('')
      .map((c) => int.tryParse(c) == null ? c : digits[int.parse(c)])
      .join();
}

/// The Self-diagnosis area: the published tests plus supporting guides.
class SelfAssessmentHomeScreen extends ConsumerStatefulWidget {
  const SelfAssessmentHomeScreen({super.key});

  @override
  ConsumerState<SelfAssessmentHomeScreen> createState() =>
      _SelfAssessmentHomeScreenState();
}

class _SelfAssessmentHomeScreenState
    extends ConsumerState<SelfAssessmentHomeScreen> {
  late Future<(List<SelfAssessmentTest>, List<ContentResource>)> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<(List<SelfAssessmentTest>, List<ContentResource>)> _load() async {
    final section = resourceSectionBySlug('self-diagnosis')!;
    final results = await Future.wait<Object>([
      ref.read(selfAssessmentRepositoryProvider).listTests(),
      ref
          .read(resourcesRepositoryProvider)
          .browseResources(
            types: section.types,
            categoryPrefixes: section.categoryPrefixes,
          )
          .catchError((_) => const <ContentResource>[]),
    ]);
    final tests = (results[0] as List<SelfAssessmentTest>)
        .where((test) => test.isPublished)
        .toList(growable: false);
    final guides = [...results[1] as List<ContentResource>]
      ..sort(compareResourcesByOrder);
    return (tests, guides);
  }

  void _reload() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সেলফ ডায়াগনোসিস')),
      body: FutureBuilder<(List<SelfAssessmentTest>, List<ContentResource>)>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(label: 'টেস্ট আনা হচ্ছে…');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'টেস্ট আনা যাচ্ছে না। আবার চেষ্টা করুন।',
              onRetry: _reload,
            );
          }
          final (tests, guides) = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              const SukunPageIntro(title: 'লক্ষণ মিলিয়ে দেখুন'),
              const SizedBox(height: 12),
              const _DisclaimerCard(),
              const SizedBox(height: 20),
              const SukunSectionHeader(title: 'টেস্ট নির্বাচন করুন'),
              const SizedBox(height: 10),
              if (tests.isEmpty)
                const AppEmptyState(
                  title: 'এখনো কোনো টেস্ট নেই',
                  message: 'পরে আবার দেখুন।',
                )
              else
                for (final test in tests) ...[
                  _NavCard(
                    key: Key('self-test-${test.slug}'),
                    icon: Icons.fact_check_outlined,
                    title: test.titleBn,
                    subtitle:
                        '${_bnDigits(test.questions.length)}টি প্রশ্ন'
                        '${test.descriptionBn?.trim().isNotEmpty == true ? ' · ${test.descriptionBn!.trim()}' : ''}',
                    onTap: () => context.push(
                      '$selfDiagnosisPath/test/${Uri.encodeComponent(test.slug)}',
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              if (guides.isNotEmpty) ...[
                const SizedBox(height: 14),
                const SukunSectionHeader(title: 'প্রয়োজনীয় নির্দেশনা'),
                const SizedBox(height: 10),
                for (final guide in guides) ...[
                  _NavCard(
                    key: Key('self-guide-${guide.id}'),
                    icon: Icons.menu_book_outlined,
                    title: guide.titleBn?.trim().isNotEmpty == true
                        ? guide.titleBn!
                        : guide.title,
                    subtitle: guide.summary,
                    onTap: () => context.push(
                      '/resources/${Uri.encodeComponent(guide.id)}',
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Answer one test, then see its result on the same screen.
class SelfAssessmentTestScreen extends ConsumerStatefulWidget {
  const SelfAssessmentTestScreen({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<SelfAssessmentTestScreen> createState() =>
      _SelfAssessmentTestScreenState();
}

class _SelfAssessmentTestScreenState
    extends ConsumerState<SelfAssessmentTestScreen> {
  late Future<SelfAssessmentTest?> _test;
  final _answers = <String, int>{};
  final _scroll = ScrollController();
  SelfAssessmentResult? _result;

  @override
  void initState() {
    super.initState();
    _test = ref.read(selfAssessmentRepositoryProvider).getTest(widget.slug);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _submit(SelfAssessmentTest test) {
    final missing = [
      for (var i = 0; i < test.questions.length; i++)
        if (!_answers.containsKey(test.questions[i].id)) i + 1,
    ];
    if (missing.isNotEmpty) {
      final shown = missing.take(5).map(_bnDigits).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'অনুগ্রহ করে সব প্রশ্নের উত্তর দিন। বাকি প্রশ্ন: $shown'
            '${missing.length > 5 ? '…' : ''}',
          ),
        ),
      );
      return;
    }
    setState(() => _result = scoreSelfAssessment(test, _answers));
    _scroll.jumpTo(0);
  }

  void _restart() {
    setState(() {
      _answers.clear();
      _result = null;
    });
    _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SelfAssessmentTest?>(
      future: _test,
      builder: (context, snapshot) {
        final test = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: Text(test?.titleBn ?? 'সেলফ টেস্ট')),
          body: switch (snapshot.connectionState) {
            ConnectionState.waiting => const AppLoadingState(
              label: 'প্রশ্ন আনা হচ্ছে…',
            ),
            _ when snapshot.hasError => AppErrorState(
              message: 'টেস্ট আনা যাচ্ছে না। আবার চেষ্টা করুন।',
              onRetry: () => setState(
                () => _test = ref
                    .read(selfAssessmentRepositoryProvider)
                    .getTest(widget.slug),
              ),
            ),
            _ when test == null || test.questions.isEmpty =>
              const AppEmptyState(
                title: 'টেস্ট পাওয়া যায়নি',
                message: 'অন্য টেস্ট দেখুন।',
              ),
            _ =>
              _result == null
                  ? _questions(context, test)
                  : _resultView(context, test, _result!),
          },
        );
      },
    );
  }

  Widget _questions(BuildContext context, SelfAssessmentTest test) {
    final answered = test.questions
        .where((question) => _answers.containsKey(question.id))
        .length;
    final total = test.questions.length;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        LinearProgressIndicator(
          value: total == 0 ? 0 : answered / total,
          minHeight: 4,
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: total + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (test.descriptionBn?.trim().isNotEmpty == true)
                        Text(
                          test.descriptionBn!.trim(),
                          style: SukunTypography.banglaBody(
                            textStyle: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'আপনার সাথে যে লক্ষণগুলো মিলে, সেগুলোর সঠিক উত্তর বেছে নিন।',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }
              final question = test.questions[index - 1];
              return _QuestionCard(
                key: Key('self-question-${question.id}'),
                number: index,
                question: question,
                selected: _answers[question.id],
                onSelected: (option) =>
                    setState(() => _answers[question.id] = option),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_bnDigits(answered)}/${_bnDigits(total)} উত্তর দেওয়া হয়েছে',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                FilledButton.icon(
                  key: const Key('self-test-submit'),
                  onPressed: () => _submit(test),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('ফলাফল দেখুন'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultView(
    BuildContext context,
    SelfAssessmentTest test,
    SelfAssessmentResult result,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        SukunSurface(
          key: const Key('self-test-result'),
          tone: SukunSurfaceTone.navy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SukunStatusPill(
                label: result.needsRuqyah
                    ? 'রুকইয়াহ করা উপকারী হতে পারে'
                    : 'বিশেষ রুকইয়াহর প্রয়োজন কম',
                tone: result.needsRuqyah
                    ? SukunStatusTone.warning
                    : SukunStatusTone.success,
              ),
              const SizedBox(height: 14),
              Text(
                result.messageBn,
                style: SukunTypography.banglaBody(
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (test.scoresByDimension && test.dimensions.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SukunSectionHeader(title: 'বিষয়ভিত্তিক স্কোর'),
          const SizedBox(height: 8),
          for (final dimension in test.dimensions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                result.flaggedDimensions.contains(dimension.key)
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: result.flaggedDimensions.contains(dimension.key)
                    ? scheme.error
                    : scheme.primary,
              ),
              title: Text(dimension.labelBn),
              trailing: Text(
                _bnDigits(result.dimensionScores[dimension.key] ?? 0),
              ),
            ),
        ],
        const SizedBox(height: 18),
        Text(
          'মিলে যাওয়া লক্ষণ: ${_bnDigits(result.matchedQuestions.length)}টি',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final question in result.matchedQuestions.take(40))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '• ${question.questionBn}',
              style: SukunTypography.banglaBody(
                textStyle: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        const SizedBox(height: 18),
        if (test.noteBn?.trim().isNotEmpty == true) ...[
          _DisclaimerCard(text: test.noteBn!.trim()),
          const SizedBox(height: 18),
        ],
        if (result.needsRuqyah) ...[
          FilledButton.icon(
            key: const Key('self-test-open-ruqyah'),
            onPressed: () => context.go('/resources/ruqyah'),
            icon: const Icon(Icons.headphones_rounded),
            label: const Text('রুকইয়াহ অডিও দেখুন'),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          key: const Key('self-test-restart'),
          onPressed: _restart,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('আবার টেস্ট দিন'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => context.go(selfDiagnosisPath),
          child: const Text('অন্য টেস্ট দেখুন'),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final int number;
  final SelfAssessmentQuestion question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SukunSurface(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_bnDigits(number)}. ${question.questionBn}',
              style: SukunTypography.banglaBody(
                textStyle: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < question.options.length; i++)
                  ChoiceChip(
                    key: Key('self-option-${question.id}-$i'),
                    label: Text(question.options[i].label),
                    selected: selected == i,
                    onSelected: (_) => onSelected(i),
                    selectedColor: scheme.primary.withValues(alpha: 0.16),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SukunSurface(
      tone: SukunSurfaceTone.soft,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text ??
                  'এই টেস্টগুলো লক্ষণ মিলিয়ে দেখার একটি সহায়ক। এটি কোনো '
                      'চিকিৎসা বা নিশ্চিত রোগনির্ণয় নয়। শারীরিক বা মানসিক '
                      'অসুস্থতায় অবশ্যই ডাক্তারের পরামর্শ নিন।',
              style: SukunTypography.banglaBody(
                textStyle: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SukunTypography.banglaBody(
                        textStyle: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (subtitle?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
