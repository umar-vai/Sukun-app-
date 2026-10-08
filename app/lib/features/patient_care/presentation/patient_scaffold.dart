import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/l10n/app_localizations.dart';

class PatientScaffold extends StatelessWidget {
  const PatientScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.body,
    this.actions,
  });

  final String title;
  final int selectedIndex;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final copy = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: body,
      bottomNavigationBar: SukunBottomNavigation(
        selectedIndex: selectedIndex,
        onSelected: (index) {
          final route = switch (index) {
            0 => '/patient/home',
            1 => '/patient/plan',
            2 => '/patient/resources',
            3 => '/patient/progress',
            _ => '/patient/profile',
          };
          context.go(route);
        },
        destinations: [
          SukunNavDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: copy?.today ?? 'আজকের কাজ',
          ),
          SukunNavDestination(
            icon: Icons.checklist_outlined,
            selectedIcon: Icons.checklist,
            label: copy?.myPlan ?? 'আমার পরিকল্পনা',
          ),
          SukunNavDestination(
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book,
            label: copy?.resources ?? 'পাঠ ও অডিও',
          ),
          SukunNavDestination(
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights,
            label: copy?.progress ?? 'অগ্রগতি',
          ),
          SukunNavDestination(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: copy?.profile ?? 'আমার তথ্য',
          ),
        ],
      ),
    );
  }
}
