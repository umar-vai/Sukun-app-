import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_tokens.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data access for the main admin's raqi list. Every call is checked in the
/// database (`admin_add_raqi`, `admin_remove_raqi`, Super Admin read RLS).
abstract interface class StaffRepository {
  Future<List<Map<String, dynamic>>> list();
  Future<void> add({String? email, String? phone, String? name});
  Future<void> remove(String id);
}

final class SupabaseStaffRepository implements StaffRepository {
  SupabaseStaffRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> list() async {
    final rows = await _client
        .from('staff_members')
        .select('id,display_name,email,phone_digits,claimed_at,created_at')
        .isFilter('revoked_at', null)
        .order('created_at', ascending: false);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }

  @override
  Future<void> add({String? email, String? phone, String? name}) => _client.rpc(
    'admin_add_raqi',
    params: {'p_email': email, 'p_phone': phone, 'p_display_name': name},
  );

  @override
  Future<void> remove(String id) =>
      _client.rpc('admin_remove_raqi', params: {'p_staff_id': id});
}

/// Main admin adds raqis by Gmail or phone (owner request 2026-11-12). A
/// raqi who signs in with that Gmail or phone opens the admin area at once,
/// with patients and reminders only.
class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key, this.repository});

  final StaffRepository? repository;

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  late final StaffRepository _repository =
      widget.repository ?? SupabaseStaffRepository();
  late Future<List<Map<String, dynamic>>> _staff = _repository.list();

  void _reload() {
    final next = _repository.list();
    setState(() {
      _staff = next;
    });
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddRaqiSheet(repository: _repository),
    );
    if (added == true && mounted) {
      _toast('রাকি যোগ হয়েছে');
      _reload();
    }
  }

  Future<void> _remove(Map<String, dynamic> member) async {
    final name = _label(member);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$name-কে সরাবেন?'),
        content: const Text('অ্যাডমিন অংশে আর ঢুকতে পারবেন না।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('না'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('সরান'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repository.remove(member['id'] as String);
      if (!mounted) return;
      _toast('সরানো হয়েছে');
      _reload();
    } catch (_) {
      if (mounted) _toast('সরানো যায়নি। আবার চেষ্টা করুন।');
    }
  }

  static String _label(Map<String, dynamic> member) {
    final name = member['display_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    return member['email']?.toString() ??
        member['phone_digits']?.toString() ??
        'রাকি';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('রাকি ও টিম')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('staff-add'),
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('রাকি যোগ করুন'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _staff,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: _reload,
                    child: const Text('তালিকা আনা যায়নি · আবার চেষ্টা'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final staff = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  SukunSpace.page,
                  SukunSpace.sm,
                  SukunSpace.page,
                  110,
                ),
                children: [
                  if (staff.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 56),
                      child: Column(
                        children: [
                          Icon(
                            Icons.groups_2_outlined,
                            size: 48,
                            color: SukunColors.muted,
                          ),
                          const SizedBox(height: SukunSpace.md),
                          Text(
                            'এখনো কোনো রাকি নেই',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  for (final member in staff)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SukunSpace.sm),
                      child: SukunSurface(
                        key: Key('staff-${member['id']}'),
                        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                        child: Row(
                          children: [
                            SukunIconBadge(
                              icon: member['email'] != null
                                  ? Icons.alternate_email_rounded
                                  : Icons.phone_rounded,
                              size: 42,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _label(member),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    [
                                      member['email'],
                                      member['phone_digits'],
                                    ].whereType<String>().join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: SukunColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SukunStatusPill(
                              label: member['claimed_at'] == null
                                  ? 'অপেক্ষমাণ'
                                  : 'সক্রিয়',
                              tone: member['claimed_at'] == null
                                  ? SukunStatusTone.warning
                                  : SukunStatusTone.success,
                            ),
                            IconButton(
                              tooltip: 'সরান',
                              onPressed: () => _remove(member),
                              icon: const Icon(Icons.person_remove_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AddRaqiSheet extends StatefulWidget {
  const _AddRaqiSheet({required this.repository});

  final StaffRepository repository;

  @override
  State<_AddRaqiSheet> createState() => _AddRaqiSheetState();
}

class _AddRaqiSheetState extends State<_AddRaqiSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (email.isEmpty && phone.isEmpty) {
      setState(() => _error = 'Gmail বা ফোন নম্বর দিন');
      return;
    }
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'সঠিক ইমেইল লিখুন');
      return;
    }
    if (phone.isNotEmpty && digits.length < 11) {
      setState(() => _error = '১১ সংখ্যার ফোন নম্বর লিখুন');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.add(
        email: email.isEmpty ? null : email,
        phone: phone.isEmpty ? null : phone,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() {
        _saving = false;
        _error = error.code == '23505'
            ? 'এই রাকি আগেই যোগ করা আছে'
            : 'যোগ করা যায়নি। আবার চেষ্টা করুন।';
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'যোগ করা যায়নি। আবার চেষ্টা করুন।';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SukunSpace.page,
        0,
        SukunSpace.page,
        MediaQuery.viewInsetsOf(context).bottom + SukunSpace.page,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('রাকি যোগ করুন', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SukunSpace.lg),
          TextField(
            key: const Key('staff-name'),
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'নাম',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: SukunSpace.md),
          TextField(
            key: const Key('staff-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Gmail',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: SukunSpace.md),
          TextField(
            key: const Key('staff-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'ফোন নম্বর',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: SukunSpace.sm),
            Text(_error!, style: const TextStyle(color: SukunColors.error)),
          ],
          const SizedBox(height: SukunSpace.lg),
          FilledButton(
            key: const Key('staff-save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'যোগ হচ্ছে…' : 'যোগ করুন'),
          ),
        ],
      ),
    );
  }
}
