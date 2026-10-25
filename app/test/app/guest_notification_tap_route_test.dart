import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/app/router/app_router.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';

void main() {
  const noticeId = 'a1b2c3d4-a123-4fff-8aaa-123456789abc';

  testWidgets(
    'cold-start Guest tap waits for session before routing exactly once',
    (tester) async {
      final sessions = StreamController<AppSession>.broadcast(sync: true);
      addTearDown(sessions.close);
      final container = ProviderContainer(
        overrides: [appSessionProvider.overrideWith((ref) => sessions.stream)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SukunLifeApp(),
        ),
      );
      await tester.pump();

      final relay = container.read(notificationTapRelayProvider);
      relay.accept('universal_notice:$noticeId');
      await tester.pump();
      expect(relay.pendingUniversalNotice, noticeId);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/',
      );

      sessions.add(const AppSession.guest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/announcements/$noticeId',
      );
      expect(relay.pendingUniversalNotice, isNull);
    },
  );

  testWidgets('Guest returning from background navigates on valid public tap', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith(
          (ref) => Stream.value(const AppSession.guest()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SukunLifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    final relay = container.read(notificationTapRelayProvider);
    relay.accept('universal_notice:$noticeId');
    await tester.pump();
    await tester.pump();

    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/announcements/$noticeId',
    );
    expect(relay.pendingUniversalNotice, isNull);
  });
}
