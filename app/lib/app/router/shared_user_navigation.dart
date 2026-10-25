import 'package:flutter/material.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';

/// The same primary destinations for every authenticated non-admin account.
/// Care assignments add content, never a second navigation system.
const sharedUserRoutes = <String>[
  '/',
  '/my-routines',
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
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
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
    return 1;
  }
  // Public resources remain directly reachable from the Home grid/search,
  // and deep-linked readers still keep their safe Home navigation.
  if (path.startsWith('/resources') || path.startsWith('/patient/resources')) {
    return 2;
  }
  if (path.startsWith('/account') || path.startsWith('/patient/profile')) {
    return 3;
  }
  return 0;
}
