import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/data/prescription_documents_providers.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:sukun_life/features/patients/domain/prescription_document.dart';
import 'package:uuid/uuid.dart';

enum _PrescriptionSourceMode { typed, document }

class CreatePrescriptionScreen extends ConsumerStatefulWidget {
  const CreatePrescriptionScreen({super.key, required this.patientId});

  final String patientId;

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
      _showMessage('Choose a PDF, JPG, or PNG prescription.');
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

    setState(() => _documentFile = file);
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

  Future<void> _submitTypedPrescription() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(patientsRepositoryProvider)
          .createPrescription(
            CreatePrescriptionInput(
              patientId: widget.patientId,
              rawText: _textController.text,
              visibility: _visibility,
              sessionDate: _sessionDate,
              requestId: const Uuid().v4(),
            ),
          );
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitDocumentPrescription() async {
    final file = _documentFile;
    if (file == null) {
      _showMessage('Choose a prescription PDF or photo first.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(prescriptionDocumentsRepositoryProvider)
          .importDocument(
            PrescriptionDocumentImportInput(
              patientId: widget.patientId,
              file: file,
              visibility: _visibility,
              sessionDate: _sessionDate,
              createRequestId: const Uuid().v4(),
              extractionRequestId: const Uuid().v4(),
            ),
          );

      if (!mounted) return;
      if (!result.isReadyForReview) {
        setState(() => _mode = _PrescriptionSourceMode.typed);
        _showMessage(prescriptionDocumentManualMessage);
        return;
      }

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
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage(prescriptionDocumentManualMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
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
      appBar: AppBar(title: const Text('Record prescription')),
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
                  const SukunPageIntro(
                    eyebrow: 'Source record',
                    title: 'Record the prescription',
                    subtitle: 'Preserve the practitioner’s original instruction before creating structured actions.',
                  ),
                  const SizedBox(height: 20),
                  _SourceModeSelector(
                    value: _mode,
                    enabled: !_submitting,
                    onChanged: (value) => setState(() => _mode = value),
                  ),
                  const SizedBox(height: 20),
                  const SukunSurface(
                    tone: SukunSurfaceTone.warning,
                    showBorder: false,
                    radius: 18,
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Preserve the original source exactly. AI only creates reviewable drafts and must never invent a dose, repetition, exact time, or ruling.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                              labelText: 'Original prescription / instruction',
                              alignLabelWithHint: true,
                            ),
                            validator: validatePrescriptionText,
                          )
                        else
                          _DocumentPicker(
                            file: _documentFile,
                            enabled: !_submitting,
                            onPick: _pickDocument,
                            onClear: () => setState(() => _documentFile = null),
                          ),
                        const SizedBox(height: 18),
                        _SessionDateTile(
                          date: _sessionDate,
                          onPick: _submitting ? null : _pickDate,
                          onClear: _submitting
                              ? null
                              : () => setState(() => _sessionDate = null),
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _patientVisible,
                          onChanged: _submitting
                              ? null
                              : (value) =>
                                    setState(() => _patientVisible = value),
                          title: const Text('Visible to patient'),
                          subtitle: Text(
                            _patientVisible
                                ? 'The patient may read the preserved prescription text.'
                                : 'The source remains staff-only.',
                          ),
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
                              : Icon(
                                  _mode == _PrescriptionSourceMode.typed
                                      ? Icons.save_outlined
                                      : Icons.document_scanner_outlined,
                                ),
                          label: Text(
                            _submitting
                                ? _mode == _PrescriptionSourceMode.typed
                                      ? 'Saving…'
                                      : 'Reading securely…'
                                : _mode == _PrescriptionSourceMode.typed
                                ? 'Save prescription'
                                : 'Upload & generate draft actions',
                          ),
                        ),
                        if (_mode == _PrescriptionSourceMode.document) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'The original file stays private. Generated actions remain drafts until a Super Admin reviews them.',
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
            title: 'Type manually',
            subtitle: 'Paste or type the original instruction',
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
            title: 'Upload document',
            subtitle: 'PDF, JPG or PNG · max 10 MB',
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
            const Icon(Icons.description_outlined, color: SukunColors.deepTide),
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
              tooltip: 'Choose another file',
              onPressed: enabled ? onPick : null,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Remove file',
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
          const Icon(
            Icons.document_scanner_outlined,
            size: 42,
            color: SukunColors.deepTide,
          ),
          const SizedBox(height: 12),
          Text(
            'Upload the original prescription',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'PDF, JPG or PNG · maximum 10 MB',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: enabled ? onPick : null,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Choose file'),
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
        title: const Text('Session date'),
        subtitle: Text(date == null ? 'Not specified' : _formatDate(date!)),
        trailing: date == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: 'Clear date',
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
