import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/l10n/app_localizations.dart';

class AdminScaffold extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: SukunBottomNavigation(
        selectedIndex: selectedIndex,
        onSelected: (index) {
          if (index == selectedIndex) return;
          context.go(switch (index) {
            0 => '/admin/dashboard',
            1 => '/admin/patients',
            _ => '/admin/content',
          });
        },
        destinations: [
          SukunNavDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: copy?.adminDashboard ?? 'কাজের সারসংক্ষেপ',
          ),
          SukunNavDestination(
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
            label: copy?.adminPatients ?? 'রোগীরা',
          ),
          SukunNavDestination(
            icon: Icons.library_books_outlined,
            selectedIcon: Icons.library_books,
            label: copy?.adminContent ?? 'উপকরণ',
          ),
        ],
      ),
    );
  }
}
