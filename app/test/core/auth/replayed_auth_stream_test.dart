import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/auth/replayed_auth_stream.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'each retry replays the stored session without waiting for a new event',
    () async {
      final events = StreamController<String>.broadcast(sync: true);
      addTearDown(events.close);
      var activeUser = 'synthetic-patient';

      expect(
        await replaySnapshotAndEvents<String>(
          snapshot: () => activeUser,
          events: events.stream,
        ).first,
        'synthetic-patient',
      );

      // AuthChangeEvent is a broadcast stream and will not re-emit an old
      // initialSession after Riverpod invalidates/re-subscribes.
      expect(
        await replaySnapshotAndEvents<String>(
          snapshot: () => activeUser,
          events: events.stream,
        ).first,
        'synthetic-patient',
      );

      activeUser = 'signed-out';
      expect(
        await replaySnapshotAndEvents<String>(
          snapshot: () => activeUser,
          events: events.stream,
        ).first,
        'signed-out',
      );
    },
  );

  test(
    'subscribed events continue after snapshot and stop after cancel',
    () async {
      final events = StreamController<String>.broadcast(sync: true);
      addTearDown(events.close);
      final seen = <String>[];
      final subscription = replaySnapshotAndEvents<String>(
        snapshot: () => 'current-patient',
        events: events.stream,
      ).listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      events.add('signed-out');
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['current-patient', 'signed-out']);

      await subscription.cancel();
      events.add('other-user');
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['current-patient', 'signed-out']);
    },
  );

  test('GoTrue AuthException triggers server re-verification rather than a terminal stream error', () async {
    final events = StreamController<String>.broadcast(sync: true);
    addTearDown(events.close);
    final seen = <String>[];
    var reads = 0;
    final sub = replaySnapshotAndEvents<String>(
      snapshot: () {
        reads++;
        return 'synthetic-user';
      },
      events: events.stream,
      replayOnError: (error) => error is AuthException,
    ).listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    events.addError(const AuthException('token refresh failed'));
    await Future<void>.delayed(Duration.zero);

    expect(reads, 2);
    expect(seen, ['synthetic-user', 'synthetic-user']);
    await sub.cancel();
  });

  test('non-auth stream errors are not silently downgraded', () async {
    final events = StreamController<String>.broadcast(sync: true);
    addTearDown(events.close);
    final errors = <Object>[];
    final sub = replaySnapshotAndEvents<String>(
      snapshot: () => 'synthetic-user',
      events: events.stream,
      replayOnError: (error) => error is AuthException,
    ).listen((_) {}, onError: (Object error) => errors.add(error));
    await Future<void>.delayed(Duration.zero);
    events.addError(StateError('backend unavailable'));
    await Future<void>.delayed(Duration.zero);

    expect(errors.single, isA<StateError>());
    await sub.cancel();
  });
}
