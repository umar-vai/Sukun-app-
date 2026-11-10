import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The template list for the bulk picker and whether it can be edited.
final class CareTemplateCatalog {
  const CareTemplateCatalog({required this.templates, required this.editable});

  /// The built-in copy, used offline or before the table is reachable.
  static const builtIn = CareTemplateCatalog(
    templates: officialPrescriptionTemplates,
    editable: false,
  );

  /// Includes inactive ones; the picker hides those.
  final List<OfficialPrescriptionTemplate> templates;

  /// True only when the list came from the database.
  final bool editable;
}

abstract interface class CareTemplateRepository {
  /// Never throws: falls back to [CareTemplateCatalog.builtIn].
  Future<CareTemplateCatalog> load();

  /// Creates (empty id) or updates one template. Super Admin only, audited.
  Future<OfficialPrescriptionTemplate> save(
    OfficialPrescriptionTemplate template,
  );
}

final class SupabaseCareTemplateRepository implements CareTemplateRepository {
  const SupabaseCareTemplateRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CareTemplateCatalog> load() async {
    try {
      final rows = await _client
          .from('care_templates')
          .select()
          .order('sort_order')
          .order('id');
      final templates = [
        for (final row in rows) OfficialPrescriptionTemplate.fromJson(row),
      ];
      if (templates.isEmpty) return CareTemplateCatalog.builtIn;
      return CareTemplateCatalog(
        templates: List.unmodifiable(templates),
        editable: true,
      );
    } catch (_) {
      return CareTemplateCatalog.builtIn;
    }
  }

  @override
  Future<OfficialPrescriptionTemplate> save(
    OfficialPrescriptionTemplate template,
  ) async {
    final row = await _client.rpc(
      'admin_save_care_template',
      params: {'p_template': template.toSaveJson()},
    );
    return OfficialPrescriptionTemplate.fromJson(
      Map<String, dynamic>.from(row as Map),
    );
  }
}

final careTemplateRepositoryProvider = Provider<CareTemplateRepository>(
  (ref) => SupabaseCareTemplateRepository(Supabase.instance.client),
);
