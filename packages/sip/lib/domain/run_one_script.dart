import 'dart:isolate';

import 'package:sip/domain/command_to_run.dart';
import 'package:sip/domain/run_script.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_console/domain/sip_console.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class RunOneScript implements RunScript {
  const RunOneScript({
    required this.command,
    required this.bindings,
  });

  final CommandToRun command;
  final Bindings bindings;

  @override
  Future<ExitCode> run() async {
    getIt<SipConsole>().l(command.label ?? command.command);

    final result = await Isolate.run(() async {
      final cmd = 'cd ${command.workingDirectory} && ${command.command}';

      final result = await bindings.runScript(cmd, showOutput: false);

      return result;
    });

    return result == ExitCode.success.code
        ? ExitCode.success
        : ExitCode.ioError;
  }
}
