// ignore_for_file: avoid_private_typedef_functions

import 'dart:async';

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/bindings.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/deps/time.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/message.dart';
import 'package:sip_cli/src/domain/message_action.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/time.dart';

typedef _RunFunction =
    Future<CommandResult> Function({bool? showOutputOverride});

class ScriptRunner {
  const ScriptRunner();

  Future<CommandResult> run(
    List<Runnable> scripts, {
    required bool bail,
    bool disableConcurrency = false,
    bool showOutput = true,
    MessageAction? Function(Runnable, Message)? onMessage,
    bool logTime = true,
    bool printLabels = true,
  }) async {
    final groups = <List<ScriptToRun>>[];
    final group = <ScriptToRun>[];

    for (final command in scripts) {
      switch (command) {
        case ConcurrentBreak():
          groups.add([...group]);
          group.clear();
        case ScriptToRun():
          group.add(command);
      }
    }

    if (group.isNotEmpty) {
      groups.add([...group]);
    }

    var result = const CommandResult(exitCode: 0, output: '', error: '');

    for (final group in groups) {
      logger.detail('\nRunning ${group.length} scripts');
      result = await _runScripts(
        group,
        bail: bail,
        showOutput: showOutput,
        printLabels: printLabels,
        disableConcurrency: disableConcurrency,
        onMessage: onMessage,
      );

      if (result.exitCodeReason != ExitCode.success) {
        return result;
      }
    }

    if (logTime) {
      final t = time.snapshot(TimeKey.core);
      logger.info(darkGray.wrap('\nFinished in $t'));
    }

    return result;
  }

  Future<CommandResult> _runScripts(
    List<ScriptToRun> scripts, {
    required bool bail,
    required bool showOutput,
    required bool printLabels,
    required bool disableConcurrency,
    required MessageAction? Function(Runnable, Message)? onMessage,
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
              onOutput: (message) {
                return onMessage(script, message);
              },
              bail: script.bail,
            );
          }

          return bindings.runScript(
            execute,
            showOutput: switch (showOutputOverride ?? showOutput) {
              false => false,
              true => switch (script.runInParallel) {
                true when !disableConcurrency => false,
                _ => true,
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
        if (showOutput) {
          logger.write('\n');
        }

        if (printLabels) {
          if (part case ScriptToRun(:final String label)) {
            logger.info('${cyan.wrap(label)}');
          }
        }

        final result = await future();
        final shouldBail = switch (part) {
          ScriptToRun(bail: true) => true,
          _ => bail,
        };

        if (result.exitCodeReason != ExitCode.success && shouldBail) {
          if (part case ScriptToRun(:final label)) {
            logger.err('$label ${red.wrap('failed')}');
          }

          return result;
        }
      }
    } else {
      final tasks = _group(
        pending,
        printLabels: printLabels,
        showOutput: showOutput,
      );

      var count = 0;

      String label() {
        final counter = magenta.wrap('$count/${pending.length}')!;
        return 'Running $counter';
      }

      final done = switch (onMessage != null || showOutput) {
        true => null,
        false => logger.progress(label()),
      };

      CommandResult? result;
      await for (final (part, taskResult) in tasks) {
        done?.update(label());
        count++;
        result = taskResult;

        if (taskResult.exitCodeReason != ExitCode.success && bail) {
          final label = part.label;

          if (label case final String label) {
            done?.fail('Script $label failed');
          }
          break;
        }
      }
      done
        ?..update(label())
        ..complete();

      return result ?? const CommandResult(exitCode: 0, output: '', error: '');
    }

    return const CommandResult(exitCode: 0, output: '', error: '');
  }

  Stream<(ScriptToRun, CommandResult)> _group(
    List<
      (ScriptToRun, Future<CommandResult> Function({bool? showOutputOverride}))
    >
    pending, {
    required bool printLabels,
    required bool showOutput,
  }) async* {
    if (pending.isEmpty) {
      throw Exception('Unexpected: No scripts to run');
    }

    final controller = StreamController<(ScriptToRun, CommandResult)>();

    Completer<void>? waitForRunning;
    final running = <ScriptToRun>[];

    Progress? done;
    ({String output, bool parallel})? last;
    void Function()? updateDone;

    void log(String output) {
      if (showOutput) {
        logger.info(output);
        return;
      }

      done = logger.progress(output);
    }

    for (final (index, (part, future)) in pending.indexed) {
      if (printLabels) {
        if (part case ScriptToRun(:final String label)) {
          var current = (
            output: '${cyan.wrap(label)}',
            parallel: part.runInParallel ?? false,
          );

          if (last?.parallel case true when current.parallel) {
            current = (
              output: [?last?.output, current.output].join(', '),
              parallel: part.runInParallel ?? false,
            );

            done?.update(current.output);
          } else if (last?.parallel case true) {
            updateDone = () {
              done?.complete();
              log(current.output);
            };
          } else if (current.parallel) {
            done = logger.progress(current.output);
          } else if (last != current) {
            done?.complete();
            log(current.output);
          }

          last = current;
        }
      }

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
          updateDone?.call();
        }

        final result = await future();
        controller.add((part, result));

        if (index == pending.length - 1) {
          controller.close().ignore();
        }
      }
    }

    if (waitForRunning case final completer?) {
      completer.future.then((_) {
        done?.complete();
      }).ignore();
    }

    yield* controller.stream;
  }
}
