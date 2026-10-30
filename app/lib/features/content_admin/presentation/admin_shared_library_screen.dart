import 'package:flutter/material.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';
import 'package:sukun_life/features/resources/presentation/resources_home_screen.dart';

/// Admin sees the exact same public resource hub as users and patients.
/// Additional content publishing controls are rendered by ResourcesHomeScreen
/// for a verified Super Admin session; never fork the catalog here.
class AdminSharedLibraryScreen extends StatelessWidget {
  const AdminSharedLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => const AdminScaffold(
    title: 'সবার উপকরণ লাইব্রেরি',
    selectedIndex: 2,
    body: ResourcesHomeScreen(embedded: true),
  );
}
