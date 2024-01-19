import 'dart:async';

class StreamGroup<T> {
  final List<Stream<T>> streams;

  StreamGroup(this.streams);

  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    return StreamGroup(streams.toList()).stream;
  }

  Stream<T> get stream {
    final controller = StreamController<T>();
    final subscriptions = <StreamSubscription<T>>[];

    for (final stream in streams) {
      subscriptions.add(
        stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            subscriptions.remove(stream);
            if (subscriptions.isEmpty) {
              controller.close();
            }
          },
        ),
      );
    }

    return controller.stream;
  }
}
