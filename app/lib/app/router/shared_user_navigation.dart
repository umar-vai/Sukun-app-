import 'package:flutter/material.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

/// The same primary destinations for every authenticated non-admin account.
/// Care assignments add content, never a second navigation system.
const sharedUserRoutes = <String>[
  '/',
  '/my-routines',
  '/progress',
  '/resources',
  '/account',
];

const sharedUserDestinations = <SukunNavDestination>[
  SukunNavDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'হোম',
  ),
  SukunNavDestination(
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist,
    label: 'রুটিন',
  ),
  SukunNavDestination(
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    label: 'অগ্রগতি',
  ),
  SukunNavDestination(
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    label: 'উপকরণ',
  ),
  SukunNavDestination(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'অ্যাকাউন্ট',
  ),
];

int sharedUserNavigationIndex(String path) {
  if (path.startsWith('/my-routines') ||
      path.startsWith('/patient/today') ||
      path.startsWith('/patient/plan')) {
    return 1;
  }
  if (path.startsWith('/progress') || path.startsWith('/patient/progress')) {
    return 2;
  }
  if (path.startsWith('/resources') || path.startsWith('/patient/resources')) {
    return 3;
  }
  if (path.startsWith('/account') || path.startsWith('/patient/profile')) {
    return 4;
  }
  return 0;
}
