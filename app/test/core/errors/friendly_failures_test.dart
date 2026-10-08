import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/errors/friendly_failures.dart';
import 'package:sukun_life/core/widgets/async_states.dart';

void main() {
  testWidgets('raw server messages never appear in shared error state', (
    tester,
  ) async {
    const internal = 'PostgrestException: SQLSTATE 42501 token=secret';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppErrorState(message: internal),
        ),
      ),
    );
    expect(find.textContaining('SQLSTATE'), findsNothing);
    expect(find.textContaining('token='), findsNothing);
    expect(find.text('আবার চেষ্টা করুন'), findsNothing);
    expect(find.textContaining('তথ্যটি এখন পাওয়া যাচ্ছে না'), findsOneWidget);
  });

  testWidgets('friendly failure mapper avoids exception content', (
    tester,
  ) async {
    late String message;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) {
          message = FriendlyFailures.signIn(context);
          return const SizedBox.shrink();
        }),
      ),
    );
    expect(message, contains('প্রবেশ করা যায়নি'));
  });
}
