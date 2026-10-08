import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('unconfigured UI preview explains why sign-in is disabled', (
    tester,
  ) async {
    // The standard CI build intentionally provides no Supabase credentials.
    expect(AppEnvironment.isSupabaseConfigured, isFalse);
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('এটি শুধু ডিজাইন দেখার'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'প্রবেশ করুন'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
