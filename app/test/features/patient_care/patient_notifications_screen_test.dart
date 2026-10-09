import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/notifications/notification_inbox_providers.dart';
import 'package:sukun_life/core/notifications/notification_inbox_repository.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_notifications_screen.dart';

void main() {
  testWidgets('an empty inbox explains that no messages have arrived', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationInboxRepositoryProvider.overrideWithValue(
            _FakeInboxRepository(),
          ),
        ],
        child: const MaterialApp(home: PatientNotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('এখনো কোনো বার্তা আসেনি'), findsOneWidget);
  });

  testWidgets('patient may read a server message and open own plan', (
    tester,
  ) async {
    final repository = _FakeInboxRepository()
      ..messages = [
        PatientInboxMessage(
          id: 'event-1',
          type: 'plan_updated',
          scheduledAt: DateTime(2026, 10, 8, 10),
          opened: false,
        ),
      ];
    final router = GoRouter(
      initialLocation: '/patient/notifications',
      routes: [
        GoRoute(
          path: '/patient/notifications',
          builder: (context, state) => const PatientNotificationsScreen(),
        ),
        GoRoute(
          path: '/patient/plan',
          builder: (context, state) =>
              const Scaffold(body: Text('Own patient plan')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationInboxRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1টি নতুন বার্তা'), findsOneWidget);
    await tester.tap(find.text('আপনার পরিকল্পনায় পরিবর্তন এসেছে'));
    await tester.pumpAndSettle();

    expect(repository.openedIds, ['event-1']);
    expect(find.text('Own patient plan'), findsOneWidget);

    // The fake server deliberately keeps sending opened=false even after ack.
    // Returning and refreshing must never reintroduce an unread badge.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('0টি নতুন বার্তা'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('0টি নতুন বার্তা'), findsOneWidget);
    expect(repository.openedIds, ['event-1']);
  });

  testWidgets('notification cards fit a narrow phone with large Bangla text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeInboxRepository()
      ..messages = [
        PatientInboxMessage(
          id: 'narrow-1',
          type: 'plan_updated',
          scheduledAt: DateTime.utc(2026, 10, 9, 10),
          opened: false,
        ),
        PatientInboxMessage(
          id: 'narrow-2',
          type: 'care_reminder',
          scheduledAt: DateTime.utc(2026, 10, 9, 11),
          opened: true,
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationInboxRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const PatientNotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1টি নতুন বার্তা'), findsOneWidget);
    expect(find.text('আপনার পরিকল্পনায় পরিবর্তন এসেছে'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backend failure shows Bangla error without internals', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationInboxRepositoryProvider.overrideWithValue(
            _FakeInboxRepository()..shouldFail = true,
          ),
        ],
        child: const MaterialApp(home: PatientNotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('আবার চেষ্টা করুন'), findsWidgets);
    expect(find.textContaining('Postgrest'), findsNothing);
  });
}

final class _FakeInboxRepository implements NotificationInboxRepository {
  List<PatientInboxMessage> messages = [];
  final openedIds = <String>[];
  bool shouldFail = false;

  @override
  Future<List<PatientInboxMessage>> getRecentMessages() async {
    if (shouldFail) throw const PatientInboxException();
    return messages;
  }

  @override
  Future<void> markOpened(String id) async {
    openedIds.add(id);
  }
}
