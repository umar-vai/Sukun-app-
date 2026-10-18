import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/app/router/shared_user_navigation.dart';

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
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          IconButton(
            tooltip: 'আমার বার্তা',
            onPressed: () => context.push('/patient/notifications'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: SukunBottomNavigation(
        // Legacy clinical screens keep their old selectedIndex contract.
        selectedIndex: switch (selectedIndex) {
          2 => 3,
          3 => 2,
          _ => selectedIndex,
        },
        onSelected: (index) => context.go(sharedUserRoutes[index]),
        destinations: sharedUserDestinations,
      ),
    );
  }
}
