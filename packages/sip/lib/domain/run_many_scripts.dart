import 'dart:async';

import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_result.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/utils/exit_code.dart';

class RunManyScripts {
  const RunManyScripts({
    required this.bindings,
    required this.logger,
    required this.runOneScript,
  });

  final Bindings bindings;
  final Logger logger;
  final RunOneScript runOneScript;

  Future<List<CommandResult>> run({
    required List<CommandToRun> commands,
    required bool bail,
    required bool sequentially,
    Duration? retryAfter,
    int maxAttempts = 3,
    String label = 'Running ',
  }) async {
    final runner = _run(commands, bail: bail, sequentially: sequentially);

    final results = <CommandResult>[];

    logger.write('\n');

    String getLabel() {
      Iterable<String> create() sync* {
        yield label.trim();
        yield ' ';
        yield darkGray.wrap('| ')!;
        yield magenta.wrap('${results.length}/${commands.length}')!;
      }

      return create().join();
    }

    final done = logger.progress(getLabel());

    await for (final result in runner) {
      results.add(result);
      if (result.exitCodeReason != ExitCode.success && bail) {
        break;
      }

      if (results.length < commands.length) {
        done.update(getLabel());
      } else {
        done.update(getLabel());
        break;
      }
    }

    if (results.any((e) => e.exitCodeReason != ExitCode.success)) {
      done.fail();
    } else {
      done.complete();
    }

    return results;
  }

  Stream<CommandResult> _run(
    Iterable<CommandToRun> commands, {
    required bool bail,
    required bool sequentially,
    Duration? retryAfter,
    int maxAttempts = 3,
  }) async* {
    logger.write('\n');

    final controller = StreamController<CommandResult>();

    if (sequentially) {
      for (final command in commands) {
        final label = command.label.truncate();
        logger.info(darkGray.wrap(label));
      }
    }

    for (final command in commands) {
      final script = runOneScript.run(
        command: command,
        showOutput: false,
        retryAfter: retryAfter,
        maxAttempts: maxAttempts,
        filter: command.filterOutput,
      );

      if (sequentially) {
        yield await script;
      } else {
        final label = command.label.truncate();
        logger.info(darkGray.wrap(label));

        script.then(controller.add).ignore();
      }
    }

    if (sequentially) {
      await controller.close();
    } else {
      yield* controller.stream;
    }
  }
}

extension _StringX on String {
  String truncate([int length = 1]) {
    final lines = split('\n');
    if (lines.length > length) {
      return [...lines.take(length), '...'].join('\n');
    }

    return this;
  }
}
