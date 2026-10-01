import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/router/app_router.dart';
import 'package:sukun_life/app/theme/sukun_theme.dart';

class SukunLifeApp extends ConsumerWidget {
  const SukunLifeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Sukun Life',
      debugShowCheckedModeBanner: false,
      theme: SukunTheme.light(),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
