import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/data/prescription_documents_providers.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:sukun_life/features/patients/domain/prescription_document.dart';
import 'package:uuid/uuid.dart';

enum _PrescriptionSourceMode { typed, document }

class CreatePrescriptionScreen extends ConsumerStatefulWidget {
  const CreatePrescriptionScreen({
    super.key,
    required this.patientId,
    this.initialDocument,
  });

  final String patientId;
  // Allows deterministic PDF retry testing without invoking the native picker.
  final PrescriptionDocumentFile? initialDocument;

  @override
  ConsumerState<CreatePrescriptionScreen> createState() =>
      _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState
    extends ConsumerState<CreatePrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  DateTime? _sessionDate;
  bool _patientVisible = true;
  bool _submitting = false;
  _PrescriptionSourceMode _mode = _PrescriptionSourceMode.typed;
  PrescriptionDocumentFile? _documentFile;
  // For manual-required extraction, retry the private stored file only.
  String? _storedDocumentAttachmentId;
  bool _draftConflict = false;
  String _documentCreateRequestId = const Uuid().v4();
  String _documentExtractionRequestId = const Uuid().v4();
  // Stable IDs and the saved result prevent duplicate prescription inserts
  // when draft creation fails and the Admin retries.
  final _typedPrescriptionRequestId = const Uuid().v4();
  final _typedPlanRequestId = const Uuid().v4();
  Prescription? _savedTypedPrescription;

  @override
  void initState() {
    super.initState();
    if (widget.initialDocument != null) {
      _mode = _PrescriptionSourceMode.document;
      _documentFile = widget.initialDocument;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _sessionDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (selected != null) setState(() => _sessionDate = selected);
  }

  Future<void> _pickDocument() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final mimeType = _mimeTypeFor(picked.extension);
    if (mimeType == null) {
      _showMessage('PDF, JPG বা PNG ফাইল বাছুন।');
      return;
    }

    final file = PrescriptionDocumentFile(
      filename: picked.name,
      mimeType: mimeType,
      bytes: bytes,
    );
    final validation = validatePrescriptionDocument(file);
    if (validation != null) {
      _showMessage(validation);
      return;
    }

    setState(() {
      _documentFile = file;
      _storedDocumentAttachmentId = null;
      _draftConflict = false;
      _documentCreateRequestId = const Uuid().v4();
      _documentExtractionRequestId = const Uuid().v4();
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_mode == _PrescriptionSourceMode.typed) {
      if (!_formKey.currentState!.validate()) return;
      await _submitTypedPrescription();
      return;
    }
    await _submitDocumentPrescription();
  }

  Future<void> _submitTypedPrescription({bool generateActions = false}) async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final prescription =
          _savedTypedPrescription ??
          await ref
              .read(patientsRepositoryProvider)
              .createPrescription(
                CreatePrescriptionInput(
                  patientId: widget.patientId,
                  rawText: _textController.text,
                  visibility: _visibility,
                  sessionDate: _sessionDate,
                  requestId: _typedPrescriptionRequestId,
                ),
              );
      _savedTypedPrescription = prescription;
      if (!mounted) return;
      if (!generateActions) {
        context.pop(true);
        return;
      }

      // Keep the existing Admin review/approval and plan publish gates.
      try {
        final draft = await ref
            .read(carePlansRepositoryProvider)
            .createDraft(
              CreateCarePlanInput(
                patientId: widget.patientId,
                name: 'প্রেসক্রিপশনভিত্তিক করণীয়',
                startDate: DateUtils.dateOnly(DateTime.now()),
                prescriptionId: prescription.id,
                requestId: _typedPlanRequestId,
              ),
            );
        if (!mounted) return;
        context.pushReplacement(
          '/admin/patients/${widget.patientId}/plans/${draft.id}/actions/suggest'
          '?prescriptionId=${Uri.encodeQueryComponent(prescription.id)}',
        );
      } catch (_) {
        if (mounted) {
          _showMessage(
            'প্রেসক্রিপশন সংরক্ষিত হয়েছে, কিন্তু খসড়া পরিকল্পনা তৈরি হয়নি। '
            'আবার চেষ্টা করুন; প্রেসক্রিপশন দ্বিতীয়বার সংরক্ষণ হবে না।',
          );
        }
      }
    } catch (_) {
      if (mounted) _showMessage('প্রেসক্রিপশন সংরক্ষণ করা যায়নি।');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitDocumentPrescription() async {
    final file = _documentFile;
    if (file == null) {
      _showMessage('আগে প্রেসক্রিপশনের PDF বা ছবি বাছুন।');
      return;
    }

    setState(() => _submitting = true);
    try {
      final documents = ref.read(prescriptionDocumentsRepositoryProvider);
      final requestId = _documentExtractionRequestId;
      final existingAttachmentId = _storedDocumentAttachmentId;
      final result = existingAttachmentId == null
          ? await documents.importDocument(
              PrescriptionDocumentImportInput(
                patientId: widget.patientId,
                file: file,
                visibility: _visibility,
                sessionDate: _sessionDate,
                createRequestId: _documentCreateRequestId,
                extractionRequestId: requestId,
              ),
            )
          : await documents.retryDocumentExtraction(
              attachmentId: existingAttachmentId,
              requestId: requestId,
            );

      if (!mounted) return;
      if (!result.isReadyForReview) {
        setState(() {
          _storedDocumentAttachmentId = result.attachmentId;
          _draftConflict = result.aiResult.failureCode == 'draft_plan_conflict';
        });
        _showMessage(switch (result.aiResult.failureCode) {
          'ai_configuration_missing' =>
            // Never name the AI provider or its keys in the admin UI
            // (AGENTS.md rule 12). Offer the manual path instead.
            'স্বয়ংক্রিয়ভাবে করণীয় তৈরি এখন চালু নেই। PDF নিরাপদে সংরক্ষিত '
                'আছে। নিজে প্রেসক্রিপশন লিখে এগিয়ে যান, অথবা পরে আবার চেষ্টা করুন।',
          'draft_plan_conflict' =>
            'এই রোগীর জন্য আগে থেকেই একটি অন্য প্রেসক্রিপশনের Draft Plan আছে। '
                'সেটি Review/Complete করুন অথবা Admin-এর সাহায্য নিন। '
                'PDF আবার আপলোড করার দরকার নেই।',
          _ =>
            'PDF সংরক্ষিত আছে, কিন্তু করণীয় তৈরির সব ধাপ শেষ হয়নি। '
                'আবার চেষ্টা করুন অথবা নিজে লিখুন।',
        });
        return;
      }

      _draftConflict = false;
      final planId = result.carePlanId!;
      final prescriptionId = result.prescriptionId!;
      context.pushReplacement(
        '/admin/patients/${widget.patientId}/plans/$planId/actions/suggest'
        '?prescriptionId=${Uri.encodeQueryComponent(prescriptionId)}',
        extra: AiActionReviewSeed(
          result: result.aiResult,
          attachmentId: result.attachmentId,
        ),
      );
    } on PrescriptionDocumentException catch (error) {
      if (mounted) {
        if (error.attachmentId != null) {
          setState(() => _storedDocumentAttachmentId = error.attachmentId);
        }
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) _showMessage(prescriptionDocumentManualMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Never overwrite an older practitioner's prescription or draft silently.
  /// The server independently checks Admin permission, draft status and zero
  /// task/action records while holding locks before archiving the empty draft.
  Future<void> _resolveDraftConflict() async {
    if (_submitting || !_draftConflict || _storedDocumentAttachmentId == null) {
      return;
    }
    setState(() => _submitting = true);
    var retrySavedPdf = false;
    try {
      final repository = ref.read(carePlansRepositoryProvider);
      final plans = await repository.getPatientPlans(widget.patientId);
      if (!mounted) return;
      final drafts = plans
          .where((plan) => plan.status == CarePlanStatus.draft)
          .toList(growable: false);
      if (drafts.isEmpty) {
        setState(() => _draftConflict = false);
        _showMessage('আগের Draft আর নেই। সংরক্ষিত PDF থেকে আবার চেষ্টা করুন।');
        return;
      }
      final oldDraft = drafts.first;
      final actions = await repository.getActions(oldDraft.id);
      if (!mounted) return;
      if (actions.isNotEmpty) {
        // Stop the progress animation while awaiting Admin confirmation.
        setState(() => _submitting = false);
        final open = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('আগের Draft-এ করণীয় রয়েছে'),
            content: const Text(
              'আগের প্রেসক্রিপশনের করণীয় পরিবর্তন বা মুছে দেওয়া হবে না। '
              'আগের Draft Plan খুলে Review/Complete করুন, তারপর ফিরে এসে '
              'সংরক্ষিত PDF থেকে আবার চেষ্টা করুন।',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('পরে করব'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Draft Plan খুলুন'),
              ),
            ],
          ),
        );
        if (open == true && mounted) {
          // Push (not replace) so the preserved PDF retry is still available
          // when Admin returns from the older plan.
          context.push(
            '/admin/patients/${widget.patientId}/plans/${oldDraft.id}',
          );
        }
        return;
      }
      // A live spinner prevents dialog transitions from ever settling.
      setState(() => _submitting = false);
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('খালি Draft আর্কাইভ করবেন?'),
          content: const Text(
            'আগের Draft-এ কোনো করণীয় নেই। শুধু এই খালি Draft আর্কাইভ হবে; '
            'আগের প্রেসক্রিপশন ও ইতিহাস অক্ষত থাকবে। তারপর এই আপলোড করা '
            'PDF থেকে নতুন করণীয় তৈরির চেষ্টা করা হবে।',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('বাতিল'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('আর্কাইভ করে চালিয়ে যান'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      setState(() => _submitting = true);
      await repository.archiveEmptyDraftForPrescriptionImport(
        patientId: widget.patientId,
        planId: oldDraft.id,
        requestId: const Uuid().v4(),
      );
      if (!mounted) return;
      setState(() {
        _draftConflict = false;
        _documentExtractionRequestId = const Uuid().v4();
      });
      retrySavedPdf = true;
    } on CarePlanWorkflowException {
      if (mounted) {
        _showMessage(
          'Draft পরিবর্তন হয়েছে অথবা এতে করণীয় রয়েছে। আগের Plan খুলে '
          'Review করুন; কোনো প্রেসক্রিপশন মুছে দেওয়া হয়নি।',
        );
      }
    } catch (_) {
      if (mounted) _showMessage('Draft যাচাই করা যায়নি। আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (retrySavedPdf && mounted) {
      await _submitDocumentPrescription();
    }
  }

  PrescriptionVisibility get _visibility => _patientVisible
      ? PrescriptionVisibility.patient
      : PrescriptionVisibility.staffOnly;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('মূল নির্দেশনা লিখুন')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SukunStepper(current: 0),
                  const SizedBox(height: SukunSpace.page),
                  _SourceModeSelector(
                    value: _mode,
                    enabled: !_submitting && _savedTypedPrescription == null,
                    onChanged: (value) => setState(() => _mode = value),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 18,
                        color: SukunColors.deepTide,
                      ),
                      const SizedBox(width: SukunSpace.sm),
                      Expanded(
                        child: Text(
                          'মূল লেখা হুবহু রাখুন। AI শুধু যাচাইযোগ্য খসড়া বানায়; ডোজ, '
                          'কতবার, নির্দিষ্ট সময় বা শরয়ি বিধান নিজে থেকে বসায় না।',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: SukunColors.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SukunSpace.md),
                  SukunSurface(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_mode == _PrescriptionSourceMode.typed)
                          TextFormField(
                            controller: _textController,
                            minLines: 7,
                            maxLines: 14,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'মূল প্রেসক্রিপশন বা নির্দেশনা',
                              alignLabelWithHint: true,
                            ),
                            validator: validatePrescriptionText,
                            readOnly:
                                _submitting || _savedTypedPrescription != null,
                          )
                        else
                          _DocumentPicker(
                            file: _documentFile,
                            enabled: !_submitting,
                            onPick: _pickDocument,
                            onClear: () => setState(() {
                              _documentFile = null;
                              _storedDocumentAttachmentId = null;
                              _draftConflict = false;
                              _documentCreateRequestId = const Uuid().v4();
                              _documentExtractionRequestId = const Uuid().v4();
                            }),
                          ),
                        const SizedBox(height: 18),
                        _SessionDateTile(
                          date: _sessionDate,
                          onPick:
                              _submitting ||
                                  _savedTypedPrescription != null ||
                                  _storedDocumentAttachmentId != null
                              ? null
                              : _pickDate,
                          onClear:
                              _submitting ||
                                  _savedTypedPrescription != null ||
                                  _storedDocumentAttachmentId != null
                              ? null
                              : () => setState(() => _sessionDate = null),
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _patientVisible,
                          onChanged:
                              _submitting ||
                                  _savedTypedPrescription != null ||
                                  _storedDocumentAttachmentId != null
                              ? null
                              : (value) =>
                                    setState(() => _patientVisible = value),
                          title: const Text('রোগী দেখতে পারবেন'),
                          subtitle: Text(
                            _patientVisible
                                ? 'রোগী সংরক্ষিত মূল লেখাটি পড়তে পারবেন।'
                                : 'মূল লেখা শুধু স্টাফ দেখবেন।',
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_mode == _PrescriptionSourceMode.typed) ...[
                          FilledButton.icon(
                            onPressed: _submitting
                                ? null
                                : () => _submitTypedPrescription(
                                    generateActions: true,
                                  ),
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: const Text(
                              'সংরক্ষণ করে AI দিয়ে করণীয় তৈরি করুন',
                            ),
                          ),
                          const SizedBox(height: SukunSpace.sm),
                        ],
                        (_mode == _PrescriptionSourceMode.typed
                            ? OutlinedButton.icon
                            : FilledButton.icon)(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _mode == _PrescriptionSourceMode.typed
                                      ? Icons.save_outlined
                                      : Icons.document_scanner_outlined,
                                ),
                          label: Text(
                            _submitting
                                ? _mode == _PrescriptionSourceMode.typed
                                      ? 'সংরক্ষণ হচ্ছে…'
                                      : 'নিরাপদে পড়া হচ্ছে…'
                                : _mode == _PrescriptionSourceMode.typed
                                ? 'শুধু প্রেসক্রিপশন সংরক্ষণ করুন'
                                : _storedDocumentAttachmentId == null
                                ? 'আপলোড করে করণীয়ের খসড়া তৈরি করুন'
                                : 'সংরক্ষিত PDF থেকে আবার AI চেষ্টা করুন',
                          ),
                        ),
                        if (_mode == _PrescriptionSourceMode.document) ...[
                          if (_draftConflict &&
                              _storedDocumentAttachmentId != null) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : _resolveDraftConflict,
                              icon: const Icon(Icons.rule_folder_outlined),
                              label: const Text(
                                'আগের Draft Plan যাচাই ও সমাধান করুন',
                              ),
                            ),
                          ],
                          if (_storedDocumentAttachmentId != null) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'PDF আগেই নিরাপদে আপলোড হয়েছে। আবার চেষ্টা করলে নতুন ফাইল আপলোড হবে না।',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () => setState(
                                      () =>
                                          _mode = _PrescriptionSourceMode.typed,
                                    ),
                              icon: const Icon(Icons.edit_note_outlined),
                              label: const Text('নিজে প্রেসক্রিপশন লিখুন'),
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                            'মূল ফাইল গোপন থাকবে। সুপার অ্যাডমিন যাচাই না করা পর্যন্ত তৈরি হওয়া করণীয় খসড়া থাকবে।',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceModeSelector extends StatelessWidget {
  const _SourceModeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final _PrescriptionSourceMode value;
  final bool enabled;
  final ValueChanged<_PrescriptionSourceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SourceModeButton(
            selected: value == _PrescriptionSourceMode.typed,
            icon: Icons.edit_note_outlined,
            title: 'নিজে লিখুন',
            subtitle: 'মূল নির্দেশনা লিখুন বা পেস্ট করুন',
            onTap: enabled
                ? () => onChanged(_PrescriptionSourceMode.typed)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SourceModeButton(
            selected: value == _PrescriptionSourceMode.document,
            icon: Icons.upload_file_outlined,
            title: 'ফাইল আপলোড',
            subtitle: 'PDF, JPG বা PNG · সর্বোচ্চ ১০ MB',
            onTap: enabled
                ? () => onChanged(_PrescriptionSourceMode.document)
                : null,
          ),
        ),
      ],
    );
  }
}

class _SourceModeButton extends StatelessWidget {
  const _SourceModeButton({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SukunColors.mist : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? SukunColors.sukunBlue
                  : Theme.of(context).dividerColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected
                    ? SukunColors.deepTide
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({
    required this.file,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final PrescriptionDocumentFile? file;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (file != null) {
      return SukunSurface(
        tone: SukunSurfaceTone.soft,
        showBorder: false,
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: SukunColors.deepTide),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file!.filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(_formatBytes(file!.byteSize)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'অন্য ফাইল বাছুন',
              onPressed: enabled ? onPick : null,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'ফাইল সরান',
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: SukunColors.mist,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SukunColors.sukunBlue.withValues(alpha: .25)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 42,
            color: SukunColors.deepTide,
          ),
          const SizedBox(height: 12),
          Text(
            'মূল প্রেসক্রিপশন আপলোড করুন',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'PDF, JPG বা PNG · সর্বোচ্চ ১০ MB',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: enabled ? onPick : null,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('ফাইল বাছুন'),
          ),
        ],
      ),
    );
  }
}

class _SessionDateTile extends StatelessWidget {
  const _SessionDateTile({
    required this.date,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? date;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SukunSurface(
      radius: 18,
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.event_outlined),
        title: const Text('সেশনের তারিখ'),
        subtitle: Text(date == null ? 'নির্ধারিত নয়' : _formatDate(date!)),
        trailing: date == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: 'তারিখ মুছুন',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
        onTap: onPick,
      ),
    );
  }
}

String? _mimeTypeFor(String? extension) => switch (extension?.toLowerCase()) {
  'pdf' => 'application/pdf',
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  _ => null,
};

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
