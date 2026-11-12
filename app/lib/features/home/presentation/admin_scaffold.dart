import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/home/presentation/staff_access.dart';
import 'package:sukun_life/l10n/app_localizations.dart';

class AdminScaffold extends StatefulWidget {
  /// Tab index of the admin Account page.
  static const accountIndex = 4;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

  final String title;
  final int selectedIndex;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  @override
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ProviderScope.containerOf(
        context,
        listen: false,
      ).read(authRepositoryProvider).signOut();
      // The authenticated router handles the verified signed-out session.
      // Never navigate to a guest route before Supabase confirms sign-out.
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('লগআউট করা যায়নি। আবার চেষ্টা করুন।')),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Widget _logoutAction(BuildContext context, String label) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final icon = _signingOut
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.logout_outlined);

    if (compact) {
      return IconButton(
        key: const Key('admin-sign-out'),
        tooltip: _signingOut ? 'লগআউট হচ্ছে…' : label,
        onPressed: _signingOut ? null : _signOut,
        icon: icon,
      );
    }

    return TextButton.icon(
      key: const Key('admin-sign-out'),
      onPressed: _signingOut ? null : _signOut,
      icon: icon,
      label: Text(_signingOut ? 'লগআউট হচ্ছে…' : label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    // A raqi works with patients only: Home, Patients and Account tabs.
    final raqi = isRaqiSession(context);
    final tabs = <(int, String, SukunNavDestination)>[
      (
        0,
        '/admin/dashboard',
        const SukunNavDestination(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'হোম',
        ),
      ),
      (
        1,
        '/admin/users',
        const SukunNavDestination(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'রোগী',
        ),
      ),
      if (!raqi) ...[
        (
          2,
          '/admin/library',
          const SukunNavDestination(
            icon: Icons.library_books_outlined,
            selectedIcon: Icons.library_books,
            label: 'উপকরণ',
          ),
        ),
        (
          3,
          '/admin/announcements',
          const SukunNavDestination(
            icon: Icons.campaign_outlined,
            selectedIcon: Icons.campaign,
            label: 'নোটিশ',
          ),
        ),
      ],
      (
        AdminScaffold.accountIndex,
        '/admin/account',
        const SukunNavDestination(
          icon: Icons.account_circle_outlined,
          selectedIcon: Icons.account_circle,
          label: 'অ্যাকাউন্ট',
        ),
      ),
    ];
    final selected = tabs.indexWhere((t) => t.$1 == widget.selectedIndex);
    return Scaffold(
      appBar: AppBar(
        // The official logo, untouched, in the top corner of every admin page.
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: SukunLifeLogo(height: 36),
        ),
        leadingWidth: 64,
        titleSpacing: 4,
        title: Text(widget.title),
        actions: [
          ...?widget.actions,
          _logoutAction(context, copy?.signOut ?? 'বের হয়ে যান'),
        ],
      ),
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: SukunBottomNavigation(
        navyEmphasis: true,
        selectedIndex: selected < 0 ? 0 : selected,
        // Detail screens share an active tab with their parent. A tap must
        // still return to that tab's root instead of becoming a no-op.
        onSelected: (index) => context.go(tabs[index].$2),
        destinations: [for (final tab in tabs) tab.$3],
      ),
    );
  }
}
