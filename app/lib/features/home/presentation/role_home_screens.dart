import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';

class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const SukunLifeLogo(height: 34)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Calm support for faith and care',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Browse approved Islamic resources, or sign in to view your personal care plan.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Patient or Admin sign in'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go('/resources'),
            child: const Text('Explore Islamic Resources'),
          ),
        ],
      ),
    );
  }
}

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Admin Dashboard',
      selectedIndex: 0,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Welcome${displayName == null ? '' : ', $displayName'}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: const CircleAvatar(
                backgroundColor: SukunColors.mist,
                child: Icon(Icons.people_outline),
              ),
              title: const Text('Patients and care plans'),
              subtitle: const Text(
                'Create patient accounts, capture prescriptions, and prepare care plans.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/patients'),
            ),
          ),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: const CircleAvatar(
                backgroundColor: SukunColors.mist,
                child: Icon(Icons.menu_book_outlined),
              ),
              title: const Text('Islamic Resources library'),
              subtitle: const Text(
                'Browse the same canonical published resources available in the public and patient experiences.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/resources'),
            ),
          ),
        ],
      ),
    );
  }
}
