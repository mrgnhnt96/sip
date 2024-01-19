import 'dart:async';
import 'dart:io';

import 'package:dart_console2/dart_console2.dart';
import 'package:sip_console/domain/progress/finisher.dart';
import 'package:sip_console/domain/progress/frame.dart';
import 'package:sip_console/domain/progress/line.dart';
import 'package:sip_console/setup/setup.dart';
import 'package:sip_console/utils/stream_group.dart';

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

  Finishers start(Iterable<String> entries) {
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

    _print(group, loadingItems).ignore();

    return finishers;
  }

  Future<void> _print(
    Stream<(int, String)> group,
    List<Line> items,
  ) async {
    final console = getIt<Console>();

    console.hideCursor();

    StreamSubscription? stdinListener;

    if (console.hasTerminal) {
      stdin
        ..echoMode = false
        ..lineMode = false;

      stdinListener = stdin.listen((event) {
        print('event: $event');
        // check if ctrl+c
        const ctrlCCode = 3;
        if (event.first == ctrlCCode) {
          console.cursorDown();
          console.showCursor();
          exit(0);
        }
      });
    }

    final loadingItems = items.asMap().map((_, e) => MapEntry(e.key, e));

    bool hasEmitted = false;
    await for (final (emittedKey, frame) in group) {
      final buffer = StringBuffer();

      if (loadingItems.values.every((e) => e.isDone())) {
        console.cursorDown();
        console.showCursor();
        break;
      }

      loadingItems[emittedKey]!.updateFrame(frame);

      for (final item in loadingItems.values) {
        buffer.writeln(item.string);

        if (hasEmitted) {
          console.cursorUp();
          console.eraseLine();
        }
      }

      hasEmitted = true;

      console.write(buffer.toString());
    }

    stdinListener?.cancel();
  }
}
