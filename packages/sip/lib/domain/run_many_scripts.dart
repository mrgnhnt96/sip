import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class RunManyScripts {
  const RunManyScripts({
    required this.commands,
    required this.bindings,
    required this.logger,
  });

  final Bindings bindings;
  final Iterable<CommandToRun> commands;
  final Logger logger;

  Future<List<ExitCode>> run({String? label}) async {
    final result = await _run(commands, label: label ?? 'Running scripts');

    return result;
  }

  Future<List<ExitCode>> _run(
    Iterable<CommandToRun> commands, {
    required String label,
  }) async {
    logger.write('\n');

    final toRun = <Future<ExitCode>>[];
    for (final command in commands) {
      toRun.add(
        RunOneScript(
          command: command,
          bindings: bindings,
          logger: logger,
          showOutput: false,
        ).run(),
      );

      String label;
      final lines = command.label.split('\n');
      if (lines.length > 2) {
        label = [lines.first, '...'].join('\n');
      } else {
        label = command.label;
      }
      logger.info(darkGray.wrap(label));
    }

    logger.write('\n');

    final done = logger.progress(label);

    final exitCodes = await Future.wait(toRun);

    if (exitCodes.any((code) => code != ExitCode.success)) {
      done.fail();
    } else {
      done.complete();
    }

    return exitCodes;
  }
}
