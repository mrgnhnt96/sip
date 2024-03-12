import 'dart:async';

class StreamGroup<T> {
  StreamGroup(this.streams);

  final List<Stream<T>> streams;

  Stream<T> merge() {
    final controller = StreamController<T>.broadcast();

    final subscriptions = <StreamSubscription<T>>[];

    for (final stream in streams) {
      final subscription = stream.listen(controller.add);

      subscriptions.add(subscription);
    }

    controller.onCancel = () {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    };

    return controller.stream;
  }
}
