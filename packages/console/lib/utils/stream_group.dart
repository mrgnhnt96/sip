import 'dart:async';

class StreamGroup<T> {
  StreamGroup(this.streams);

  final List<Stream<T>> streams;

  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    return StreamGroup(streams.toList()).stream;
  }

  Stream<T> get stream {
    final controller = StreamController<T>();
    final subscriptions = <StreamSubscription<T>>[];

    for (final stream in streams) {
      late StreamSubscription<T> subscription;

      subscription = stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          subscriptions.remove(subscription);
          if (subscriptions.isEmpty) {
            controller.close();
          }
        },
      );

      subscriptions.add(subscription);
    }

    return controller.stream;
  }
}
