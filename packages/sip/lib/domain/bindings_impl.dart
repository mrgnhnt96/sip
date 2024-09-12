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
    final process = await Process.start(
      'bash',
      ['-c', script],
      runInShell: true,
    );

    stdout.hasTerminal;

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
