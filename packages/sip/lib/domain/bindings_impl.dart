import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_result.dart';

class BindingsImpl implements Bindings {
  const BindingsImpl();

  @override
  Future<CommandResult> runScript(
    String script, {
    required bool showOutput,
  }) async {
    final port = ReceivePort();

    final isolate = await Isolate.spawn(
      _runScript,
      port.sendPort,
    );

    final completer = Completer<CommandResult>();

    await for (final event in port) {
      if (event is SendPort) {
        event.send({
          'script': script,
          'showOutput': showOutput,
        });
      } else if (event is Map) {
        final result = CommandResult.fromJson(event);
        completer.complete(result);
        break;
      }
    }

    await completer.future;

    isolate.kill();

    return completer.future;
  }
}

Future<void> _runScript(SendPort sendPort) async {
  final port = ReceivePort();

  sendPort.send(port.sendPort);

  Future<CommandResult> run(String script, {required bool showOutput}) async {
    final [command, arg] = switch (Platform.operatingSystem) {
      'linux' => ['bash', '-c'],
      'macos' => ['bash', '-c'],
      'windows' => ['cmd', '/c'],
      _ => throw UnsupportedError('Unsupported platform'),
    };
    final process = await Process.start(
      command,
      [arg, script],
      runInShell: true,
      mode:
          showOutput ? ProcessStartMode.inheritStdio : ProcessStartMode.normal,
    );

    final outputBuffer = StringBuffer();
    final errorBuffer = StringBuffer();

    final outputController = StreamController<List<int>>();
    final errorController = StreamController<List<int>>();

    final outputStream = outputController.stream.asBroadcastStream();
    final errorStream = errorController.stream.asBroadcastStream();

    outputStream.transform(utf8.decoder).listen(outputBuffer.write);
    errorStream.transform(utf8.decoder).listen(errorBuffer.write);

    if (!showOutput) {
      process.stdout.listen(outputController.add);
      process.stderr.listen(errorController.add);
    }

    final code = await process.exitCode;

    process.kill();

    return CommandResult(
      exitCode: code,
      output: outputBuffer.toString(),
      error: errorBuffer.toString(),
    );
  }

  await for (final event in port) {
    if (event
        case {
          'script': final String script,
          'showOutput': final bool showOutput
        }) {
      final result = await run(script, showOutput: showOutput);

      sendPort.send(result.toJson());
    }
  }
}
