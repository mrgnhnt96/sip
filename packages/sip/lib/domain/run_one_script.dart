import 'dart:async';

import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_result.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/env_config.dart';

class RunOneScript {
  const RunOneScript({
    required CommandToRun this.command,
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

  Future<CommandResult> run() async {
    var cmd = command.command;

    logger.detail('Env files: ${command.envConfig?.files}');

    if (command.envConfig case final EnvConfig config) {
      if (config.files case final files? when files.isNotEmpty) {
        for (final file in files) {
          logger.detail('Sourcing env file $file');
          cmd = '''
if [ -f $file ]; then
  builtin source $file
else
  echo "ENV File $file not found"
  exit 1
fi

$cmd
''';
        }
      }
    }
    logger.detail('Setting directory to ${command.workingDirectory}');
    cmd = '''
cd ${command.workingDirectory} || exit 1

$cmd
''';

    var printOutput = showOutput;
    if (logger.level == Level.quiet) {
      printOutput = false;
    }

    logger.detail('''
--------- SCRIPT ---------
${cmd}
--------------------------
''');

    final runScript = bindings.runScript(cmd, showOutput: printOutput);

    CommandResult codeResult;
    final retryAfter = this.retryAfter;
    if (retryAfter == null) {
      logger.detail('Not retrying');
      final result = await runScript;

      codeResult = result;
    } else {
      logger.detail('Retrying command after $retryAfter');
      var hasExited = false;
      var attempt = 0;

      while (!hasExited && attempt < maxAttempts) {
        attempt++;

        final controller = StreamController<CommandResult?>();

        final wait = retryAfter + (retryAfter * (.1 * attempt));

        logger.detail('Waiting $wait before attempt $attempt');

        final timer = Timer(wait, () => controller.add(null));

        runScript.then(controller.add).ignore();

        final exitCode = await controller.stream.first;

        timer.cancel();

        if (exitCode == null) {
          continue;
        }

        codeResult = exitCode;
        hasExited = true;
      }

      logger.detail(
        'Native failed to exit after $maxAttempts attempts, '
        'running without retries',
      );

      final result = await runScript;

      codeResult = result;
    }

    logger.detail('Native exited with ${codeResult.exitCode}');

    return codeResult;
  }
}
