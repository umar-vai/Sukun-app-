import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';

/// Admin-only route. Supabase policies independently enforce authorization.
class AdminRoutineTemplatesScreen extends StatefulWidget {
  const AdminRoutineTemplatesScreen({super.key});

  @override
  State<AdminRoutineTemplatesScreen> createState() =>
      _AdminRoutineTemplatesScreenState();
}

class _AdminRoutineTemplatesScreenState
    extends State<AdminRoutineTemplatesScreen> {
  late Future<List<Map<String, dynamic>>> _templates;
  bool _saving = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final rows = await _client
        .from('routine_templates')
        .select(
          'id,title,description,status,created_at,'
          'routine_template_steps(id,title,sort_order)',
        )
        .order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  void _reload() {
    _templates = _fetch();
    if (mounted) setState(() {});
  }

  Future<String?> _askTitle(String heading) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(heading),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'নাম'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.trim().isNotEmpty == true ? result!.trim() : null;
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createTemplate() async {
    final title = await _askTitle('নতুন প্রস্তুত রুটিন');
    if (title == null || _saving) return;
    await _mutate(() async {
      final owner = _client.auth.currentUser?.id;
      if (owner == null) throw StateError('Admin login required');
      await _client.from('routine_templates').insert({
        'title': title,
        'created_by': owner,
        'status': 'draft',
      });
    });
  }

  Future<void> _addStep(String id, int currentCount) async {
    final title = await _askTitle('নতুন আমল');
    if (title == null || _saving) return;
    await _mutate(() async {
      await _client.from('routine_template_steps').insert({
        'template_id': id,
        'title': title,
        'sort_order': currentCount,
      });
    });
  }

  Future<void> _deleteStep(String stepId) => _mutate(() async {
    await _client.from('routine_template_steps').delete().eq('id', stepId);
  });

  Future<void> _setPublished({
    required String id,
    required bool publish,
    required int count,
  }) async {
    if (publish && count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('প্রথমে অন্তত একটি আমল যোগ করুন।')),
      );
      return;
    }
    await _mutate(() async {
      await _client
          .from('routine_templates')
          .update({
            'status': publish ? 'published' : 'draft',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    });
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: 'প্রস্তুত রুটিন',
    selectedIndex: 2,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _saving ? null : _createTemplate,
      icon: const Icon(Icons.add),
      label: const Text('নতুন রুটিন'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _templates,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text('আবার চেষ্টা করুন'),
            ),
          );
        }
        final templates = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 95),
          children: [
            if (templates.isEmpty)
              const ListTile(
                leading: Icon(Icons.edit_note_outlined),
                title: Text('এখনো কোনো প্রস্তুত রুটিন নেই'),
              ),
            for (final template in templates)
              Card(
                key: Key('admin-routine-template-${template['id']}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(template['title'].toString()),
                        subtitle: Text(
                          template['status'] == 'published'
                              ? 'প্রকাশিত'
                              : 'খসড়া',
                        ),
                      ),
                      for (final step in
                          (template['routine_template_steps'] as List? ?? const []))
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text((step as Map)['title'].toString()),
                          trailing: template['status'] == 'draft'
                              ? IconButton(
                                  tooltip: 'আমল সরান',
                                  onPressed: _saving
                                      ? null
                                      : () => _deleteStep(step['id'] as String),
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : null,
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (template['status'] == 'draft')
                            OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _addStep(
                                      template['id'] as String,
                                      (template['routine_template_steps'] as List?)
                                              ?.length ??
                                          0,
                                    ),
                              icon: const Icon(Icons.add),
                              label: const Text('আমল যোগ করুন'),
                            ),
                          FilledButton(
                            onPressed: _saving
                                ? null
                                : () => _setPublished(
                                    id: template['id'] as String,
                                    publish: template['status'] != 'published',
                                    count: (template['routine_template_steps']
                                                as List?)
                                            ?.length ??
                                        0,
                                  ),
                            child: Text(
                              template['status'] == 'published'
                                  ? 'প্রকাশ বন্ধ করুন'
                                  : 'প্রকাশ করুন',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
