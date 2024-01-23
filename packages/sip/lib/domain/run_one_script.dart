import 'dart:isolate';

import 'package:sip/domain/command_to_run.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_console/domain/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class RunOneScript {
  const RunOneScript({
    required this.command,
    required this.bindings,
    this.showOutput = true,
  });

  final CommandToRun command;
  final Bindings bindings;
  final bool showOutput;

  Future<ExitCode> run() async {
    getIt<SipConsole>().l(darkGray.wrap(command.label) ?? command.label);

    final result = await Isolate.run(() async {
      final cmd = 'cd ${command.workingDirectory} && ${command.command}';

      final result = await bindings.runScript(cmd, showOutput: showOutput);

      return result;
    });

    final codes = {
      ExitCode.success.code: ExitCode.success,
      ExitCode.usage.code: ExitCode.usage,
      ExitCode.data.code: ExitCode.data,
      ExitCode.noInput.code: ExitCode.noInput,
      ExitCode.noUser.code: ExitCode.noUser,
      ExitCode.noHost.code: ExitCode.noHost,
      ExitCode.unavailable.code: ExitCode.unavailable,
      ExitCode.software.code: ExitCode.software,
      ExitCode.osError.code: ExitCode.osError,
      ExitCode.osFile.code: ExitCode.osFile,
      ExitCode.cantCreate.code: ExitCode.cantCreate,
      ExitCode.ioError.code: ExitCode.ioError,
      ExitCode.tempFail.code: ExitCode.tempFail,
      ExitCode.noPerm.code: ExitCode.noPerm,
      ExitCode.config.code: ExitCode.config,
    };

    return codes[result] ?? ExitCode.success;
  }
}
