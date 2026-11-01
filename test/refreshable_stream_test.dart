import 'dart:async';

import 'package:budgeto/refreshable_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'mutation refresh delivers current server value when live stream stays stale',
    () async {
      final live = StreamController<int>.broadcast();
      final mutations = StreamController<void>.broadcast();
      var serverValue = 1;
      final received = <int>[];
      final subscription = watchWithRefresh<int>(
        live.stream,
        mutations.stream,
        () async => serverValue,
      ).listen(received.add);
      live.add(1);
      await Future<void>.delayed(Duration.zero);
      serverValue = 2;
      mutations.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received, [1, 2]);
      await subscription.cancel();
      await live.close();
      await mutations.close();
    },
  );
}
