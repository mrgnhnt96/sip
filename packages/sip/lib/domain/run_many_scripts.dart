import 'dart:async';

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

  Future<List<ExitCode>> run({
    required bool bail,
    String label = 'Running ',
  }) async {
    final runner = _run(
      commands,
      bail: bail,
    );

    final exitCodes = <ExitCode>[];

    logger.write('\n');

    String getLabel() {
      Iterable<String> create() sync* {
        yield label;
        yield darkGray.wrap('| ')!;
        yield magenta.wrap('${exitCodes.length}/${commands.length}')!;
      }

      return create().join();
    }

    final done = logger.progress(getLabel());

    await for (final exitCode in runner.asBroadcastStream()) {
      exitCodes.add(exitCode);
      if (exitCode != ExitCode.success && bail) {
        done.fail();
        return exitCodes;
      }

      if (exitCodes.length < commands.length) {
        done.update(getLabel());
      } else {
        done.update(getLabel());
        break;
      }
    }

    if (exitCodes.any((code) => code != ExitCode.success)) {
      done.fail();
    } else {
      done.complete();
    }

    return exitCodes;
  }

  Stream<ExitCode> _run(
    Iterable<CommandToRun> commands, {
    required bool bail,
  }) {
    logger.write('\n');

    final controller = StreamController<ExitCode>();

    for (final command in commands) {
      final script = RunOneScript(
        command: command,
        bindings: bindings,
        logger: logger,
        showOutput: false,
      );

      String label;
      final lines = command.label.split('\n');
      if (lines.length > 2) {
        label = [lines.first, '...'].join('\n');
      } else {
        label = command.label;
      }
      logger.info(darkGray.wrap(label));

      script.run().then(controller.add);
    }

    return controller.stream;
  }
}
