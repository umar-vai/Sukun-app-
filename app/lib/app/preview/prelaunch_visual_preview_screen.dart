import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';

/// A deliberately disconnected design review surface.
/// No login is bypassed in connected, native or production applications.
class PrelaunchVisualPreviewScreen extends StatelessWidget {
  const PrelaunchVisualPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সুকুন লাইফ · ডিজাইন প্রিভিউ')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SukunLifeLogo(height: 82)),
                  const SizedBox(height: 24),
                  Text(
                    'মোবাইল অ্যাপের ডিজাইন যাচাই করুন',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'এটি শুধু স্ক্রিন ও নেভিগেশন দেখার সংস্করণ। '
                    'কোনো বাস্তব অ্যাকাউন্টে লগইন হবে না, '
                    'রোগীর তথ্য দেখা যাবে না বা পরিবর্তন হবে না। '
                    'যেসব স্ক্রিনে সার্ভারের তথ্য লাগে, সেখানে খালি বা '
                    'তথ্য আনা যাচ্ছে না এমন বার্তা আসতে পারে।',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 22),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.personal_injury_outlined,
                        color: SukunColors.deepTide,
                      ),
                      title: const Text('রোগীর প্যানেল দেখুন'),
                      subtitle: const Text('আজকের কাজ, পরিকল্পনা ও নেভিগেশন'),
                      trailing: const Icon(Icons.arrow_forward_rounded),
                      onTap: () => context.go('/patient/home'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: SukunColors.deepTide,
                      ),
                      title: const Text('অ্যাডমিন প্যানেল দেখুন'),
                      subtitle: const Text('ড্যাশবোর্ড, রোগী ও উপকরণ ব্যবস্থাপনা'),
                      trailing: const Icon(Icons.arrow_forward_rounded),
                      onTap: () => context.go('/admin/dashboard'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.login_rounded,
                        color: SukunColors.deepTide,
                      ),
                      title: const Text('লগইন স্ক্রিন দেখুন'),
                      subtitle: const Text('ফর্মের ডিজাইন; প্রবেশ করা যাবে না'),
                      trailing: const Icon(Icons.arrow_forward_rounded),
                      onTap: () => context.go('/login'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'ফিরে আসতে ব্রাউজারের Back বোতাম ব্যবহার করুন। '
                    'বাস্তব লগইন ও কাজ পরীক্ষা করতে আলাদা '
                    'staging-connected সংস্করণ প্রয়োজন।',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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
