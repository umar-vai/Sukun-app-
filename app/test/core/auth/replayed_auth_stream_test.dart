import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/auth/replayed_auth_stream.dart';

void main() {
  test('each retry replays the stored session without waiting for a new event', () async {
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
  });

  test('subscribed events continue after snapshot and stop after cancel', () async {
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
  });
}
