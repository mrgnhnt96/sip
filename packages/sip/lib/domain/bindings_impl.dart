import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_result.dart';
import 'package:sip_cli/domain/filter_type.dart';

class BindingsImpl implements Bindings {
  const BindingsImpl();

  @override
  Future<CommandResult> runScript(
    String script, {
    required bool showOutput,
    FilterType? filterType,
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
          'filterType': filterType?.name,
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

  Future<CommandResult> run(
    String script, {
    required bool showOutput,
    FilterType? type,
  }) async {
    final [command, arg] = switch (Platform.operatingSystem) {
      'linux' => ['bash', '-c'],
      'macos' => ['bash', '-c'],
      'windows' => ['cmd', '/c'],
      _ => throw UnsupportedError('Unsupported platform'),
    };

    final filterOutput = type?.filter;
    final formatter = type?.formatter;

    final hasTerminal = switch ((showOutput, filterOutput != null)) {
      (false, _) => false,
      (_, true) => false,
      _ => true,
    };
    final process = await Process.start(
      command,
      [arg, script],
      runInShell: true,
      mode: switch (hasTerminal) {
        false => ProcessStartMode.normal,
        _ => ProcessStartMode.inheritStdio,
      },
    );

    final outputBuffer = StringBuffer();
    final errorBuffer = StringBuffer();

    final outputController = StreamController<List<int>>();
    final errorController = StreamController<List<int>>();

    final outputStream = outputController.stream.asBroadcastStream();
    final errorStream = errorController.stream.asBroadcastStream();

    outputStream.transform(utf8.decoder).listen(outputBuffer.write);
    errorStream.transform(utf8.decoder).listen(errorBuffer.write);

    final filter = filterOutput ?? (_) => false;

    outputStream.transform(utf8.decoder).listen((event) {
      if (!filter(event)) {
        return;
      }

      final message = formatter?.call(event) ?? event;

      stdout.write(message);
    });

    if (!hasTerminal) {
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
          'showOutput': final bool showOutput,
          'filterType': final String? type,
        }) {
      final result = await run(
        script,
        showOutput: showOutput,
        type: FilterType.fromString(type),
      );

      sendPort.send(result.toJson());
    }
  }
}
