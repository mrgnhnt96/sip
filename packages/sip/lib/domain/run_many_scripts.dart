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
  }) : sequentially = false;

  const RunManyScripts.sequentially({
    required this.commands,
    required this.bindings,
    required this.logger,
  }) : sequentially = true;

  final Bindings bindings;
  final Iterable<CommandToRun> commands;
  final Logger logger;
  final bool sequentially;

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

    await for (final exitCode in runner) {
      exitCodes.add(exitCode);
      if (exitCode != ExitCode.success && bail) {
        break;
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
  }) async* {
    logger.write('\n');

    final controller = StreamController<ExitCode>();

    if (sequentially) {
      for (final command in commands) {
        final label = command.label.truncate();
        logger.info(darkGray.wrap(label));
      }
    }

    for (final command in commands) {
      final script = RunOneScript(
        command: command,
        bindings: bindings,
        logger: logger,
        showOutput: false,
      );

      if (sequentially) {
        yield await script.run();
      } else {
        final label = command.label.truncate();
        logger.info(darkGray.wrap(label));

        script.run().then(controller.add).ignore();
      }
    }

    yield* controller.stream;
  }
}

extension _StringX on String {
  String truncate([int length = 1]) {
    final lints = split('\n');
    if (lints.length > length) {
      return [...lints.take(length), '...'].join('\n');
    }

    return this;
  }
}
