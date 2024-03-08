import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class RunOneScript {
  const RunOneScript({
    required this.command,
    required this.bindings,
    required this.logger,
    required this.showOutput,
  });

  final CommandToRun command;
  final Bindings bindings;
  final bool showOutput;
  final Logger logger;

  Future<ExitCode> run() async {
    logger.detail('Setting directory to ${command.workingDirectory}');

    final cmd = 'cd ${command.workingDirectory} && ${command.command}';

    var printOutput = showOutput;
    if (logger.level == Level.quiet) {
      printOutput = false;
    }

    final result = await bindings.runScript(cmd, showOutput: printOutput);

    logger.detail('Native exited with $result');

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

    return codes[result] ?? ExitCode.unknown(result);
  }
}
