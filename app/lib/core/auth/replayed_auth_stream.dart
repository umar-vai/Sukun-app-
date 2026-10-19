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
}) {
  late final StreamController<T> controller;
  late final StreamSubscription<T> subscription;
  controller = StreamController<T>(onCancel: () => subscription.cancel());
  subscription = events.listen(
    controller.add,
    onError: controller.addError,
    onDone: controller.close,
  );
  try {
    controller.add(snapshot());
  } catch (error, stackTrace) {
    controller.addError(error, stackTrace);
  }
  return controller.stream;
}
