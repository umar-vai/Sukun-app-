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
          const SizedBox(height: 24),
          Text(
            'Daily utilities',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _UtilityCard(
                  icon: Icons.schedule_outlined,
                  label: 'Prayer times',
                  onTap: () => context.push('/prayer-times'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _UtilityCard(
                  icon: Icons.explore_outlined,
                  label: 'Qibla',
                  onTap: () => context.push('/qibla'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UtilityCard extends StatelessWidget {
  const _UtilityCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, color: SukunColors.deepTide, size: 30),
              const SizedBox(height: 9),
              Text(label, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
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
                'Create, review, verify, publish, and archive canonical resources.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/content'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Daily utilities',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _UtilityCard(
                  icon: Icons.schedule_outlined,
                  label: 'Prayer times',
                  onTap: () => context.push('/prayer-times'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _UtilityCard(
                  icon: Icons.explore_outlined,
                  label: 'Qibla',
                  onTap: () => context.push('/qibla'),
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => context.go('/resources'),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview published public library'),
          ),
        ],
      ),
    );
  }
}
