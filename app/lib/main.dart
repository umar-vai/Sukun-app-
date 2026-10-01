import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/core/config/app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnvironment.initialize();
  runApp(const ProviderScope(child: SukunLifeApp()));
}
