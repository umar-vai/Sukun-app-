import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:uuid/uuid.dart';

class CreateCarePlanScreen extends ConsumerStatefulWidget {
  const CreateCarePlanScreen({
    super.key,
    required this.patientId,
    this.initialPrescriptionId,
    this.copyFromPlanId,
  });

  final String patientId;
  final String? initialPrescriptionId;
  final String? copyFromPlanId;

  @override
  ConsumerState<CreateCarePlanScreen> createState() =>
      _CreateCarePlanScreenState();
}

class _CreateCarePlanScreenState extends ConsumerState<CreateCarePlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Care Plan');
  final _requestId = const Uuid().v4();
  late Future<List<Prescription>> _prescriptions;
  late DateTime _startDate;
  DateTime? _endDate;
  String _prescriptionId = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateUtils.dateOnly(DateTime.now());
    _prescriptionId = widget.initialPrescriptionId ?? '';
    _prescriptions = ref
        .read(patientsRepositoryProvider)
        .getPrescriptions(widget.patientId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected == null) return;
    setState(() {
      _startDate = selected;
      if (_endDate?.isBefore(selected) == true) _endDate = null;
    });
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null) setState(() => _endDate = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      final plan = await ref
          .read(carePlansRepositoryProvider)
          .createDraft(
            CreateCarePlanInput(
              patientId: widget.patientId,
              name: _nameController.text,
              startDate: _startDate,
              endDate: _endDate,
              prescriptionId: _prescriptionId.isEmpty ? null : _prescriptionId,
              copyFromPlanId: widget.copyFromPlanId,
              requestId: _requestId,
            ),
          );
      if (mounted) context.pop(plan);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'পরিকল্পনা তৈরি করা যায়নি। তথ্যগুলো দেখে আবার চেষ্টা করুন।',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewVersion = widget.copyFromPlanId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewVersion ? 'নতুন সংস্করণ' : 'নতুন সেবা পরিকল্পনা'),
      ),
      body: FutureBuilder<List<Prescription>>(
        future: _prescriptions,
        builder: (context, snapshot) {
          final prescriptions = snapshot.data ?? const <Prescription>[];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SukunPageIntro(
                        eyebrow: 'রোগীর সেবা',
                        title: isNewVersion
                            ? 'নতুন খসড়া সংস্করণ'
                            : 'সেবা পরিকল্পনা তৈরি করুন',
                        subtitle: 'নাম ও মূল নির্দেশনা দিন। করণীয় পরের ধাপে যোগ ও যাচাই করবেন।',
                        trailing: const SukunIconBadge(
                          icon: Icons.assignment_add,
                          size: 54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (isNewVersion) ...[
                        const SukunSurface(
                          tone: SukunSurfaceTone.warning,
                          showBorder: false,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.copy_all_outlined,
                                color: SukunColors.deepTide,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Actions and resource links will be copied into a new draft. Every copied action is marked “Needs review” and must be approved again before publishing.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      SukunSurface(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              onTap: () {
                                if (_nameController.text == 'Care Plan') {
                                  _nameController.selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: _nameController.text.length,
                                  );
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'পরিকল্পনার নাম',
                                prefixIcon: Icon(Icons.assignment_outlined),
                              ),
                              validator: validatePlanName,
                            ),
                            const SizedBox(height: 14),
                            SukunChoiceField<String>(
                              value: _prescriptionId,
                              label: 'মূল প্রেসক্রিপশন (যদি থাকে)',
                              placeholder: 'মূল নির্দেশনা বাছুন',
                              options: [
                                const SukunChoiceOption(
                                  value: '',
                                  title: 'প্রেসক্রিপশন যুক্ত নয়',
                                  description:
                                      'মূল নির্দেশনা ছাড়া খসড়া তৈরি করুন।',
                                  icon: Icons.edit_note_rounded,
                                ),
                                for (final prescription in prescriptions)
                                  SukunChoiceOption(
                                    value: prescription.id,
                                    title:
                                        'Recorded ${_formatDate(prescription.createdAt)}',
                                    description: prescription.rawText,
                                    icon: Icons.description_outlined,
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _prescriptionId = value),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        initiallyExpanded: isNewVersion,
                        title: const Text('শুরু ও শেষ তারিখ'),
                        subtitle: Text(
                          '${_formatDate(_startDate)} থেকে'
                          '${_endDate == null ? ' · শেষ তারিখ নেই' : ' · ${_formatDate(_endDate!)} পর্যন্ত'}',
                        ),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _DateTile(
                                  label: 'শুরুর তারিখ',
                                  value: _startDate,
                                  onTap: _pickStartDate,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DateTile(
                                  label: 'শেষ তারিখ',
                                  value: _endDate,
                                  onTap: _pickEndDate,
                                  onClear: _endDate == null
                                      ? null
                                      : () => setState(() => _endDate = null),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_task),
                        label: Text(
                          _submitting
                              ? 'খসড়া তৈরি হচ্ছে…'
                              : isNewVersion
                              ? 'নতুন খসড়া সংস্করণ তৈরি করুন'
                              : 'খসড়া তৈরি করে করণীয় যোগ করুন',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      radius: 20,
      padding: const EdgeInsets.all(15),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SukunIconBadge(icon: Icons.event_outlined, size: 40),
              const Spacer(),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Clear date',
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: SukunColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            value == null ? 'No end date' : _formatDate(value!),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
