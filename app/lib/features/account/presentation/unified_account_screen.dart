import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sukun_life/core/updates/android_update_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// All signed-in people have the same account destination.
class UnifiedAccountScreen extends ConsumerStatefulWidget {
  const UnifiedAccountScreen({super.key});

  @override
  ConsumerState<UnifiedAccountScreen> createState() =>
      _UnifiedAccountScreenState();
}

class _UnifiedAccountScreenState extends ConsumerState<UnifiedAccountScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('লগআউট করা যাচ্ছে না। আবার চেষ্টা করুন।')),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).value;
    final user = Supabase.instance.client.auth.currentUser;
    final name = session?.displayName?.trim();
    final isPatient = session?.isPatient == true;
    return Scaffold(
      appBar: AppBar(title: const Text('আমার অ্যাকাউন্ট')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    child: Icon(Icons.person_outline, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name == null || name.isEmpty ? 'সুকুন সদস্য' : name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'লগইন করা অ্যাকাউন্ট',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('account-audio-library'),
                  leading: const Icon(Icons.library_music_outlined),
                  title: const Text('আমার প্লেলিস্ট ও ডাউনলোড'),
                  subtitle: const Text('সংরক্ষিত অডিও শুনুন ও প্লেলিস্ট দেখুন'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/my-media'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.checklist_outlined),
                  title: const Text('আমার রুটিন'),
                  subtitle: const Text('নিজের করণীয় ও রিমাইন্ডার'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/my-routines'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('অগ্রগতি ও হিস্ট্রি'),
                  subtitle: const Text('৭ ও ৩০ দিনের কাজের রেকর্ড'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/progress'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: const Text('নোটিশ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/announcements'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.text_fields_outlined),
                  title: const Text('অ্যাপ, ফন্ট ও রিডার সেটিংস'),
                  subtitle: const Text(
                    'অটো/ডার্ক মোড, বাংলা ও আরবি ফন্টের আকার',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/appearance'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('নোটিফিকেশন ও রিমাইন্ডার'),
                  subtitle: const Text('অনুমতি পরীক্ষা ও রিমাইন্ডার চালু/বন্ধ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/notifications'),
                ),

                if (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.android) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.system_update_alt),
                    title: const Text('অ্যাপ আপডেট চেক করুন'),
                    subtitle: const Text('অফিসিয়াল নতুন APK সংস্করণ খুঁজুন'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => checkAndroidUpdateManually(context),
                  ),
                ],
              ],
            ),
          ),
          if (isPatient) ...[
            const SizedBox(height: 14),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: const Text('সুকুন লাইফের দেওয়া পরিকল্পনা'),
                    subtitle: const Text(
                      'আপনার অ্যাকাউন্টে অনুমোদিত পরিকল্পনা থাকলে দেখুন',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/patient/plan'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('চিকিৎসা-সংক্রান্ত সেটিংস'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/patient/profile'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout_outlined),
            label: Text(_signingOut ? 'লগআউট হচ্ছে…' : 'লগআউট'),
          ),
        ],
      ),
    );
  }
}
