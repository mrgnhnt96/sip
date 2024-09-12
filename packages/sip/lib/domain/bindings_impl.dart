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
      [
        '-c',
        script,
      ],
      runInShell: true,
    );

    final outputBuffer = StringBuffer();
    final errorBuffer = StringBuffer();

    process.stdout.transform(utf8.decoder).listen(outputBuffer.write);
    process.stderr.transform(utf8.decoder).listen(errorBuffer.write);

    if (showOutput) {
      process.stdout.listen(stdout.add);
      process.stderr.listen(stderr.add);
    }

    final code = await process.exitCode;

    return CommandResult(
      exitCode: code,
      output: outputBuffer.toString(),
      error: errorBuffer.toString(),
    );
  }
}
