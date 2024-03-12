import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// Type of Map<dynamic, void Function()>
typedef KeyMap = Map<dynamic, FutureOr<void> Function()>;

typedef Event = void Function();

/// {@template key_press_listener}
/// A class that listens for key presses from [stdin]
/// and emits the key presses to the stream.
/// {@endtemplate}
class KeyPressListener {
  /// {@macro key_press_listener}
  KeyPressListener({
    required this.logger,
  });

  final Logger logger;

  /// we only need one stream for stdin
  static Stream<List<int>>? _stream;

  /// listens to keystrokes
  Stream<void>? listenToKeystrokes({
    required Event onExit,
    required Event onEscape,
    Map<String, Event>? customStrokes,
  }) {
    if (!stdin.hasTerminal) {
      return null;
    }

    stdin
      ..lineMode = false
      ..echoMode = false;

    _stream ??= stdin.asBroadcastStream();

    final strokes = {
      'q': onExit,
      // escape key
      0x1b: onEscape,
      ...?customStrokes,
    };

    return _stream!.asyncMap((event) {
      if (event.isEmpty) return;

      logger.detail('Received keyboard event: $event');
      final key = utf8.decode(event);
      logger.detail('Key pressed: $key');

      final stroke =
          strokes[key] ?? strokes[key.toLowerCase()] ?? strokes[event.first];

      stroke?.call();

      return;
    });
  }
}
