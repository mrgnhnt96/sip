// ignore_for_file: avoid_private_typedef_functions

import 'dart:async';

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/bindings.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/message.dart';
import 'package:sip_cli/src/domain/message_action.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/utils/stopwatch_extensions.dart';

// TODO: print out bailing message
// TODO: handle concurrent commands (add break between concurrent parts)

typedef _RunFunction =
    Future<CommandResult> Function({bool? showOutputOverride});

class ScriptRunner {
  const ScriptRunner();

  Future<CommandResult> run(
    List<Runnable> scripts, {
    required bool bail,
    bool disableConcurrency = false,
    bool showOutput = true,
    MessageAction? Function(Message)? onMessage,
  }) async {
    final groups = <List<ScriptToRun>>[];
    final group = <ScriptToRun>[];

    for (final command in scripts) {
      switch (command) {
        case ConcurrentBreak():
          groups.add([...group]);
          group.clear();
        case ScriptToRun(runInParallel: true):
          group.add(command);
        case final ScriptToRun script:
          groups.addAll([
            if (group.isNotEmpty) [...group],
            [script],
          ]);
          group.clear();
      }
    }

    if (group.isNotEmpty) {
      groups.add([...group]);
    }

    var result = const CommandResult(exitCode: 0, output: '', error: '');

    final stopwatch = Stopwatch()..start();

    for (final group in groups) {
      result = await _runScripts(
        group,
        bail: bail,
        showOutput: showOutput,
        disableConcurrency: disableConcurrency,
        onMessage: onMessage,
      );

      if (result.exitCodeReason != ExitCode.success) {
        return result;
      }
    }

    final time = (stopwatch..stop()).format();
    logger.info(darkGray.wrap('Finished in $time'));

    return result;
  }

  Future<CommandResult> _runScripts(
    List<ScriptToRun> scripts, {
    required bool bail,
    required bool showOutput,
    required bool disableConcurrency,
    required MessageAction? Function(Message)? onMessage,
  }) async {
    final pending = <(ScriptToRun, _RunFunction)>[];

    final backupWorkingDirectory = switch (scriptsYaml.nearest()) {
      final String path => fs.file(path).parent.path,
      _ => null,
    };

    for (final script in scripts) {
      final workingDirectory = switch (script.workingDirectory) {
        final String dir => dir,
        _ => backupWorkingDirectory,
      };

      if (workingDirectory == null) {
        throw Exception(
          'Unexpected: working directory is expected but is null',
        );
      }

      final variables = switch (script.variables) {
        final map when map.isNotEmpty => [
          for (final MapEntry(:key, :value) in map.entries)
            'export $key=$value',
        ].join('\n'),
        _ => null,
      };

      logger.detail('CWD: $workingDirectory');
      final execute = [
        'cd "$workingDirectory" || exit 1',
        ?variables,
        script.exe,
      ].join('\n\n');

      pending.add((
        script,
        ({bool? showOutputOverride}) {
          if (onMessage case final onMessage?) {
            return bindings.runScriptWithOutput(
              execute,
              onOutput: onMessage,
              bail: script.bail,
            );
          }

          return bindings.runScript(
            execute,
            showOutput: switch (showOutputOverride ?? showOutput) {
              false => false,
              true => switch (script.runInParallel) {
                true => false,
                null || false => false,
              },
            },
            bail: script.bail,
          );
        },
      ));
    }

    if (disableConcurrency) {
      logger.detail('Running ${pending.length} scripts sequentially');
      for (final (part, future) in pending) {
        final result = await future();
        final shouldBail = switch (part) {
          ScriptToRun(bail: true) => true,
          _ => bail,
        };

        if (result.exitCodeReason != ExitCode.success && shouldBail) {
          if (part case ScriptToRun(:final label)) {
            logger.err('Script $label failed');
          }

          return result;
        }
      }
    } else {
      final tasks = _group(pending);

      var count = 0;

      String label() {
        final counter = magenta.wrap('$count/${pending.length}')!;
        return 'Running $counter';
      }

      final done = switch (scripts.length) {
        1 => null,
        _ => logger.progress(label()),
      };
      await for (final (part, result) in tasks) {
        done?.update(label());
        count++;

        if (result.exitCodeReason != ExitCode.success && bail) {
          final label = part.label;

          if (label case final String label) {
            done?.fail('Script $label failed');
          }
          break;
        }
      }
      done?.update(label());
      done?.complete();

      return const CommandResult(exitCode: 0, output: '', error: '');
    }

    return const CommandResult(exitCode: 0, output: '', error: '');
  }

  Stream<(ScriptToRun, CommandResult)> _group(
    List<
      (ScriptToRun, Future<CommandResult> Function({bool? showOutputOverride}))
    >
    pending,
  ) async* {
    if (pending.isEmpty) {
      throw Exception('Unexpected: No scripts to run');
    }

    final controller = StreamController<(ScriptToRun, CommandResult)>();

    for (final (part, _) in pending) {
      if (part case ScriptToRun(:final label)) {
        logger.info(darkGray.wrap(label));
      }
    }

    Completer<void>? waitForRunning;
    final running = <ScriptToRun>[];

    for (final (index, (part, future)) in pending.indexed) {
      if (part.runInParallel case true) {
        running.add(part);
        waitForRunning ??= Completer<void>();

        future(showOutputOverride: false).then((result) {
          running.remove(part);
          controller.add((part, result));

          if (running.isEmpty) {
            waitForRunning?.complete();
            controller.close().ignore();
          }
        }).ignore();
      } else {
        if (waitForRunning case final completer?) {
          await completer.future;
          waitForRunning = null;
        }

        final result = await future(showOutputOverride: false);
        controller.add((part, result));

        if (index == pending.length - 1) {
          controller.close().ignore();
        }
      }
    }

    yield* controller.stream;
  }
}
