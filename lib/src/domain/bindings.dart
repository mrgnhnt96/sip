import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/deps/fs.dart';
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
    return _run(script, bail: bail, showOutput: showOutput);
  }

  Future<CommandResult> runScriptWithOutput(
    String script, {
    required MessageAction? Function(Message) onOutput,
    bool bail = false,
  }) {
    return _run(script, bail: bail, showOutput: false, onOutput: onOutput);
  }

  Future<CommandResult> _run(
    String script, {
    required bool bail,
    required bool showOutput,
    MessageAction? Function(Message)? onOutput,
  }) async {
    final port = ReceivePort();

    final isolate = await Isolate.spawn(_runScript, port.sendPort);

    final completer = Completer<CommandResult>();
    StreamSubscription<dynamic>? subscription;

    void kill() {
      try {
        isolate.kill();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(
            const CommandResult(exitCode: 1, output: '', error: ''),
          );
        }
      } catch (_) {
        // ignore
      }
    }

    subscription = port.listen((event) {
      switch (event) {
        case final SendPort sendPort:
          sendPort.send({
            'script': script,
            'bail': bail,
            'showOutput': showOutput,
          });
        case {'message': final String message, 'isError': final bool isError}:
          final msg = Message(message, isError: isError);
          final action = onOutput?.call(msg);
          switch (action) {
            case null:
              break;
            case MessageAction.kill:
              kill();
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
  await runScoped(values: {processProvider, fsProvider}, () async {
    final port = ReceivePort();

    sendPort.send(port.sendPort);

    Future<CommandResult> run(
      String script, {
      required bool bail,
      required bool showOutput,
    }) async {
      final [command, arg] = switch (Platform.operatingSystem) {
        'linux' => ['bash', '-c'],
        'macos' => ['bash', '-c'],
        'windows' => ['cmd', '/c'],
        _ => throw UnsupportedError('Unsupported platform'),
      };

      final details = await process(
        command,
        [arg, script],
        runInShell: false,
        mode: switch (showOutput) {
          true => ProcessStartMode.inheritStdio,
          false => ProcessStartMode.normal,
        },
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

      final code = await details.exitCode;

      details.kill();

      return CommandResult(
        exitCode: code,
        output: outputBuffer.toString(),
        error: errorBuffer.toString(),
      );
    }

    await for (final event in port) {
      if (event case {
        'script': final String script,
        'bail': final bool bail,
        'showOutput': final bool showOutput,
      }) {
        final result = await run(script, bail: bail, showOutput: showOutput);

        sendPort.send(result.toJson());
      }
    }
  });
}
