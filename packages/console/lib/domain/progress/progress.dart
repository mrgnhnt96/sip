import 'dart:async';
import 'dart:io';

import 'package:dart_console2/dart_console2.dart';
import 'package:sip_console/domain/progress/finisher.dart';
import 'package:sip_console/domain/progress/frame.dart';
import 'package:sip_console/domain/progress/line.dart';
import 'package:sip_console/setup/setup.dart';
import 'package:sip_console/utils/stream_group.dart';

/// A progress animation.
class Progress {
  Progress({
    this.frames = const Frame.defaults(),
  });

  final Frame frames;

  Stream<(int, String)> _stream(
    int key, {
    required bool Function() isDone,
  }) async* {
    var i = 0;

    var keepGoing = true;
    while (keepGoing) {
      if (isDone()) {
        keepGoing = false;
      }
      final frame = frames.progress.get(i++);
      yield (key, frame);
      await frames.progress.step();
    }

    return;
  }

  Finishers start(Iterable<String> entries, void Function() onFinish) {
    final mapped = entries.toList().asMap();
    final loadingItems = mapped.entries.map((e) {
      return Line(
        key: e.key,
        frames: frames,
        text: e.value,
      );
    }).toList();

    final streams = loadingItems.map(
      (e) => _stream(
        e.key,
        isDone: e.isDone,
      ),
    );

    final finishers = Finishers(
      loadingItems.map((e) {
        return FinisherImpl(finish: e.finish);
      }),
    );

    final group = StreamGroup.merge(streams);

    _print(
      group,
      loadingItems,
      onFinish,
    ).ignore();

    return finishers;
  }

  Future<void> _print(
    Stream<(int, String)> group,
    List<Line> items,
    void Function() onFinish,
  ) async {
    final console = getIt<Console>()..hideCursor();

    StreamSubscription<dynamic>? stdinListener;

    if (console.hasTerminal) {
      stdin
        ..echoMode = false
        ..lineMode = false;

      stdinListener = stdin.listen((event) {
        // check if ctrl+c
        const ctrlCCode = 3;
        if (event.first == ctrlCCode) {
          console
            ..cursorDown()
            ..showCursor();
          exit(0);
        }
      });
    }

    final loadingItems = items.asMap().map((_, e) => MapEntry(e.key, e));

    void write(Map<int, Line> items, {bool hasEmitted = true}) {
      final buffer = StringBuffer();

      for (final item in loadingItems.values) {
        buffer.writeln(item.string);

        if (hasEmitted) {
          console
            ..cursorUp()
            ..eraseLine();
        }
      }

      console.write(buffer.toString());
    }

    write(loadingItems, hasEmitted: false);

    await for (final (emittedKey, frame) in group) {
      loadingItems[emittedKey]!.updateFrame(frame);

      if (loadingItems.values.every((e) => e.isDone())) {
        break;
      }

      write(loadingItems);
    }

    // write last time to solidify final state
    await Future.sync(() => write(loadingItems));

    console
      ..cursorDown()
      ..showCursor();

    await stdinListener?.cancel();

    onFinish();
  }
}
