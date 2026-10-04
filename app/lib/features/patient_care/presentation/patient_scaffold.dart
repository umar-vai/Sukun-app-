import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

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
        destinations: const [
          SukunNavDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Today',
          ),
          SukunNavDestination(
            icon: Icons.checklist_outlined,
            selectedIcon: Icons.checklist,
            label: 'My Plan',
          ),
          SukunNavDestination(
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book,
            label: 'Resources',
          ),
          SukunNavDestination(
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights,
            label: 'Progress',
          ),
          SukunNavDestination(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
