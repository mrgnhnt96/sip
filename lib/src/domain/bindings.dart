import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/on_death.dart';
import 'package:sip_cli/src/deps/platform.dart';
import 'package:sip_cli/src/deps/process.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/message.dart';
import 'package:sip_cli/src/domain/message_action.dart';

class Bindings {
  const Bindings();

  Future<CommandResult> runScript(
    String script, {
    required bool showOutput,
    bool bail = false,
  }) {
    return _run(script, bail: bail, showOutput: showOutput, sendOutput: false);
  }

  Future<CommandResult> runScriptWithOutput(
    String script, {
    required MessageAction? Function(Message) onOutput,
    bool bail = false,
  }) {
    return _run(
      script,
      bail: bail,
      showOutput: false,
      onOutput: onOutput,
      sendOutput: true,
    );
  }

  Future<CommandResult> _run(
    String script, {
    required bool bail,
    required bool showOutput,
    required bool sendOutput,
    MessageAction? Function(Message)? onOutput,
  }) async {
    final port = ReceivePort();

    final isolate = await Isolate.spawn(_runScript, port.sendPort);

    final completer = Completer<CommandResult>();
    StreamSubscription<dynamic>? subscription;

    SendPort? sendPort;

    void kill() {
      try {
        isolate.kill(priority: Isolate.immediate);
      } catch (_) {}

      try {
        subscription?.cancel();
      } catch (_) {}

      if (!completer.isCompleted) {
        completer.complete(
          const CommandResult(exitCode: 1, output: '', error: ''),
        );
      }
    }

    onDeath.register(kill);

    subscription = port.listen((event) {
      switch (event) {
        case final SendPort port:
          sendPort = port;
          port.send({
            'script': script,
            'bail': bail,
            'showOutput': showOutput,
            'sendOutput': sendOutput,
          });
        case {'message': final String message, 'isError': final bool isError}:
          final msg = Message(message, isError: isError);
          switch (onOutput?.call(msg)) {
            case null:
              break;
            case MessageAction.kill:
              sendPort?.send('KILL');
          }
        case {
          'exitCode': final int code,
          'output': final String output,
          'error': final String error,
        }:
          completer.complete(
            CommandResult(exitCode: code, output: output, error: error),
          );
      }

      if (completer.isCompleted) {
        subscription?.cancel();
      }
    });

    final result = await completer.future;

    kill();

    return result;
  }
}

Future<void> _runScript(SendPort sendPort) async {
  await runScoped(
    values: {processProvider, fsProvider, platformProvider},
    () async {
      final port = ReceivePort();

      sendPort.send(port.sendPort);

      Future<(void Function() kill, Future<CommandResult>)> run(
        String script, {
        required bool bail,
        required bool showOutput,
        required bool sendOutput,
      }) async {
        final [command, arg] = switch (Platform.operatingSystem) {
          'linux' => ['bash', '-c'],
          'macos' => ['bash', '-c'],
          'windows' => ['cmd', '/c'],
          _ => throw UnsupportedError('Unsupported platform'),
        };

        // sendOutput = true
        var mode = ProcessStartMode.normal;

        if (showOutput && !sendOutput) {
          mode = ProcessStartMode.inheritStdio;
        }

        final details = await process(
          command,
          [arg, script],
          runInShell: false,
          mode: mode,
        );

        final outputBuffer = StringBuffer();
        final errorBuffer = StringBuffer();

        details.stdout.listen((event) {
          if (event.trim().isEmpty) return;

          sendPort.send(Message(event).toJson());
          outputBuffer.write(event);
        });

        details.stderr.listen((event) {
          if (event.trim().isEmpty) return;

          sendPort.send(Message(event, isError: true).toJson());
          errorBuffer.write(event);
        });

        final future = details.exitCode.then((code) {
          details.kill();

          return CommandResult(
            exitCode: code,
            output: outputBuffer.toString(),
            error: errorBuffer.toString(),
          );
        });

        return (details.kill, future);
      }

      final killers = <void Function()>[];

      await for (final event in port) {
        switch (event) {
          case 'KILL':
            for (final kill in killers) {
              kill();
            }
            killers.clear();
            sendPort.send('KILL_DONE');
          case {
            'script': final String script,
            'bail': final bool bail,
            'showOutput': final bool showOutput,
            'sendOutput': final bool sendOutput,
          }:
            final (kill, result) = await run(
              script,
              bail: bail,
              showOutput: showOutput,
              sendOutput: sendOutput,
            );

            killers.add(kill);

            result.then((result) => sendPort.send(result.toJson())).ignore();
        }
      }
    },
  );
}
