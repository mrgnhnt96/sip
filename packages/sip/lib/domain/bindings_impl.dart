import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_result.dart';

class BindingsImpl implements Bindings {
  const BindingsImpl();

  @override
  Future<CommandResult> runScript(
    String script, {
    bool showOutput = true,
  }) async {
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
      mode: ProcessStartMode.inheritStdio,
    );

    final outputBuffer = StringBuffer();
    final errorBuffer = StringBuffer();

    final outputController = StreamController<List<int>>();
    final errorController = StreamController<List<int>>();

    process.stdout.listen(outputController.add);
    process.stderr.listen(errorController.add);

    final outputStream = outputController.stream.asBroadcastStream();
    final errorStream = errorController.stream.asBroadcastStream();

    outputStream.transform(utf8.decoder).listen(outputBuffer.write);
    errorStream.transform(utf8.decoder).listen(errorBuffer.write);

    if (showOutput) {
      outputStream.listen(stdout.add);
      errorStream.listen(stderr.add);
    }

    final code = await process.exitCode;

    return CommandResult(
      exitCode: code,
      output: outputBuffer.toString(),
      error: errorBuffer.toString(),
    );
  }
}
