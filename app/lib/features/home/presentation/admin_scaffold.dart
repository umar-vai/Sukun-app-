import 'package:flutter/material.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/home/presentation/staff_access.dart';
import 'package:sukun_life/l10n/app_localizations.dart';

class AdminScaffold extends StatefulWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.body,
    this.floatingActionButton,
    this.actions,
    this.heroAppBar = false,
  });

  final String title;
  final int selectedIndex;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  /// Dashboard-style app bar that blends into a [SukunHeroHeader].
  final bool heroAppBar;

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
        color: widget.heroAppBar ? Colors.white : null,
        tooltip: _signingOut ? 'লগআউট হচ্ছে…' : label,
        onPressed: _signingOut ? null : _signOut,
        icon: icon,
      );
    }

    return TextButton.icon(
      key: const Key('admin-sign-out'),
      style: widget.heroAppBar
          ? TextButton.styleFrom(foregroundColor: Colors.white)
          : null,
      onPressed: _signingOut ? null : _signOut,
      icon: icon,
      label: Text(_signingOut ? 'লগআউট হচ্ছে…' : label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    // A raqi works with patients only: Home and Patients tabs.
    final raqi = isRaqiSession(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.heroAppBar ? SukunColors.deepTide : null,
        foregroundColor: widget.heroAppBar ? Colors.white : null,
        title: Text(widget.title),
        titleTextStyle: widget.heroAppBar
            ? Theme.of(context).appBarTheme.titleTextStyle
                  ?.copyWith(color: Colors.white)
            : null,
        actionsIconTheme: widget.heroAppBar
            ? const IconThemeData(color: Colors.white)
            : null,
        actions: [
          ...?widget.actions,
          _logoutAction(context, copy?.signOut ?? 'বের হয়ে যান'),
        ],
      ),
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: SukunBottomNavigation(
        navyEmphasis: true,
        selectedIndex: raqi
            ? widget.selectedIndex.clamp(0, 1)
            : widget.selectedIndex,
        onSelected: (index) {
          // Detail screens share an active tab with their parent. A tap must
          // still return to that tab's root instead of becoming a no-op.
          context.go(switch (index) {
            0 => '/admin/dashboard',
            1 => '/admin/users',
            2 => '/admin/library',
            _ => '/admin/announcements',
          });
        },
        destinations: [
          SukunNavDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: copy?.adminDashboard ?? 'অ্যাডমিন হোম',
          ),
          SukunNavDestination(
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: 'রোগী',
          ),
          if (!raqi) ...[
            const SukunNavDestination(
              icon: Icons.library_books_outlined,
              selectedIcon: Icons.library_books,
              label: 'উপকরণ',
            ),
            const SukunNavDestination(
              icon: Icons.campaign_outlined,
              selectedIcon: Icons.campaign,
              label: 'নোটিশ',
            ),
          ],
        ],
      ),
    );
  }
}
