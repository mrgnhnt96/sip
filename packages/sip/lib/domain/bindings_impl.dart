import 'dart:io';

import 'package:sip_cli/domain/bindings.dart';

class BindingsImpl implements Bindings {
  const BindingsImpl();

  @override
  Future<int> runScript(String script, {bool showOutput = true}) async {
    final process = await Process.start(
      'bash',
      [
        '-c',
        script,
      ],
      runInShell: true,
    );

    if (showOutput) {
      process.stdout.listen(stdout.add);
      process.stderr.listen(stderr.add);
    }

    final code = await process.exitCode;

    return code;
  }
}
