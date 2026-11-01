import 'dart:async';

Stream<T> watchWithRefresh<T>(
  Stream<T> live,
  Stream<void> refresh,
  Future<T> Function() reload,
) {
  late final StreamController<T> controller;
  StreamSubscription<T>? liveSubscription;
  StreamSubscription<void>? refreshSubscription;
  controller = StreamController<T>(
    onListen: () {
      liveSubscription = live.listen(
        controller.add,
        onError: controller.addError,
      );
      refreshSubscription = refresh.listen((_) async {
        try {
          final value = await reload();
          if (!controller.isClosed) controller.add(value);
        } catch (_) {
          // Keep the last live value if the explicit server refresh is offline.
        }
      });
    },
    onCancel: () async {
      await liveSubscription?.cancel();
      await refreshSubscription?.cancel();
    },
  );
  return controller.stream;
}
