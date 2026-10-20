import 'dart:async';

/// Subscribes to changes before replaying the current snapshot.
///
/// Supabase's auth change stream is a live broadcast: invalidating a
/// StreamProvider after an error must not depend on a future auth event to
/// recover. Each new subscription gets a fresh snapshot and future changes.
///
/// A snapshot may race with an auth event; consumers must still verify the
/// current authenticated user before exposing any protected role.
Stream<T> replaySnapshotAndEvents<T>({
  required T Function() snapshot,
  required Stream<T> events,
  bool Function(Object error)? replayOnError,
}) {
  late final StreamController<T> controller;
  late final StreamSubscription<T> subscription;
  controller = StreamController<T>(onCancel: () => subscription.cancel());
  subscription = events.listen(
    controller.add,
    onError: (Object error, StackTrace stackTrace) {
      // GoTrue can emit a refresh failure via the auth event broadcast even
      // while its existing access token still authorizes RLS reads. Do not
      // permanently poison the session stream if a safe re-query is possible.
      // A replay is only a user ID hint: the repository MUST verify
      // profile/role data against the backend before granting any access.
      if (replayOnError != null && replayOnError(error)) {
        try {
          controller.add(snapshot());
        } catch (replayError, replayStack) {
          controller.addError(replayError, replayStack);
        }
        return;
      }
      controller.addError(error, stackTrace);
    },
    onDone: controller.close,
  );
  try {
    controller.add(snapshot());
  } catch (error, stackTrace) {
    controller.addError(error, stackTrace);
  }
  return controller.stream;
}
