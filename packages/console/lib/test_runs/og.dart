import 'dart:async';
import 'dart:io';

import 'package:dart_console2/dart_console2.dart';

Future<void> get wait => Future.delayed(const Duration(milliseconds: 50));

Stream<int> counter(Duration waitFor) async* {
  await Future<void>.delayed(waitFor);

  var i = 0;
  while (i <= 100) {
    await wait;
    yield i++;
  }
}

Future<void> run() async {
  final console = Console();
  if (!console.hasTerminal) {
    return;
  }

  console.hideCursor();

  stdin
    ..echoMode = false
    ..lineMode = false;

  final first = Count('first', 0);
  final firstStream =
      counter(const Duration(milliseconds: 100)).asyncMap(first.update);
  final second = Count('second', 0);

  final secondStream =
      counter(const Duration(milliseconds: 200)).asyncMap(second.update);

  final joined = StreamGroup.merge([firstStream, secondStream]);

  final counts = [first, second];

  final mappedCount = {
    for (final count in counts) count.key: count.value,
  };

  bool hasEmitted = false;
  await for (final count in joined) {
    final buffer = StringBuffer();

    mappedCount[count.key] = count.value;

    for (final MapEntry(:key, :value) in mappedCount.entries) {
      buffer.writeln('$key: $value');

      if (hasEmitted) {
        console.cursorUp();
        console.eraseLine();
      }
    }

    hasEmitted = true;

    // console.cursorPosition = Coordinate(startRow, startColumn);
    console.write(buffer.toString());
  }
}

class Count {
  const Count(this.key, this.value);

  final int value;
  final String key;

  Count update(int v) => Count(key, v);

  @override
  String toString() => '$key: $value';
}

extension CoordinateX on Coordinate {
  Coordinate translateX(int x) => Coordinate(this.y, x + this.x);
  Coordinate translateY(int y) => Coordinate(y + this.y, this.x);

  Coordinate toX(int x) => Coordinate(this.y, x);
  Coordinate toY(int y) => Coordinate(y, this.x);

  Coordinate translate(int x, int y) => Coordinate(y + this.y, x + this.x);
}

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
