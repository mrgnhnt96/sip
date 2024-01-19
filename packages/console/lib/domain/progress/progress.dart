import 'dart:async';
import 'dart:io';

import 'package:dart_console2/dart_console2.dart';
import 'package:sip_console/domain/progress/line.dart';
import 'package:sip_console/domain/progress/progress_animation.dart';
import 'package:sip_console/setup/setup.dart';
import 'package:sip_console/utils/stream_group.dart';

class Progress {
  Progress({
    required this.entries,
    ProgressAnimation? animation,
  }) : animation = animation ?? ProgressAnimation();

  final List<String> entries;
  final ProgressAnimation animation;

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
      final frame = animation.frames[i++ % animation.frames.length];
      yield (key, frame);
      await Future<void>.delayed(animation.step);
    }
  }

  Iterable<void Function()> start() {
    final loadingItems = mapped.entries.map((e) {
      return Line(
        key: e.key,
        frame: animation.frames[0],
        doneFrame: animation.done,
        text: e.value,
      );
    }).toList();

    final streams = loadingItems.map(
      (e) => _stream(
        e.key,
        isDone: e.isDone,
      ),
    );

    final finishers = loadingItems.map((e) => e.finish);

    final group = StreamGroup.merge(streams);

    _print(group, loadingItems);

    return finishers;
  }

  Map<int, String> get mapped => entries.asMap();

  Future<void> _print(
    Stream<(int, String)> group,
    List<Line> items,
  ) async {
    final console = getIt<Console>();

    console.hideCursor();

    if (console.hasTerminal) {
      stdin
        ..echoMode = false
        ..lineMode = false;

      stdin.listen((event) {
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

      loadingItems[emittedKey]!.updateFrame(frame);

      for (final item in loadingItems.values) {
        if (item.isDone()) {
          buffer.writeln(item.done);
        } else {
          buffer.writeln(item.loading);
        }

        if (hasEmitted) {
          console.cursorUp();
          console.eraseLine();
        }
      }

      hasEmitted = true;

      console.write(buffer.toString());
    }
  }
}
