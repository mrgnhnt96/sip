import 'dart:async';

import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class RunOneScript {
  const RunOneScript({
    required this.command,
    required this.bindings,
    required this.logger,
    required this.showOutput,
    this.retryAfter,
    this.maxAttempts = 3,
  });

  final CommandToRun command;
  final Bindings bindings;
  final bool showOutput;
  final Logger logger;
  final Duration? retryAfter;
  final int maxAttempts;

  Future<ExitCode> run() async {
    logger.detail('Setting directory to ${command.workingDirectory}');

    var cmd = 'cd ${command.workingDirectory} && ${command.command}';

    if (command.envFile != null) {
      cmd = 'source ${command.envFile} && $cmd';
    }

    var printOutput = showOutput;
    if (logger.level == Level.quiet) {
      printOutput = false;
    }

    logger.detail('''
--------- SCRIPT ---------
${command.command}
--------------------------
''');

    final runScript = bindings.runScript(cmd, showOutput: printOutput);

    int? result;
    final retryAfter = this.retryAfter;
    if (retryAfter == null) {
      logger.detail('Not retrying');
      result = await runScript;
    } else {
      logger.detail('Retrying command after $retryAfter');
      var hasExited = false;
      var attempt = 0;

      while (!hasExited && attempt < maxAttempts) {
        attempt++;

        final controller = StreamController<int?>();

        final wait = retryAfter + (retryAfter * (.1 * attempt));

        logger.detail('Waiting $wait before attempt $attempt');

        final timer = Timer(wait, () => controller.add(null));

        runScript.then(controller.add).ignore();

        final exitCode = await controller.stream.first;

        timer.cancel();

        if (exitCode == null) {
          continue;
        }

        result = exitCode;
        hasExited = true;
      }

      logger.detail(
        'Native failed to exit after $maxAttempts attempts, '
        'running without retries',
      );

      result = await runScript;
    }

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
