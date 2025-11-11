// ignore_for_file: avoid_private_typedef_functions

import 'dart:async';

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/bindings.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/utils/stopwatch_extensions.dart';

// TODO: print out bailing message
// TODO: handle concurrent commands (add break between concurrent parts)

typedef _RunFunction =
    Future<CommandResult> Function({bool? showOutputOverride});

class ScriptRunner {
  const ScriptRunner();

  Future<CommandResult> groupRun(
    List<Runnable> scripts, {
    required bool bail,
    bool disableConcurrency = false,
    bool showOutput = true,
  }) async {
    final groups = <List<ScriptToRun>>[];
    final group = <ScriptToRun>[];

    for (final command in scripts) {
      switch (command) {
        case ConcurrentBreak():
          groups.add([...group]);
          group.clear();
        case final ScriptToRun script:
          group.add(script);
      }
    }

    if (group.isNotEmpty) {
      groups.add([...group]);
    }

    var result = const CommandResult(exitCode: 0, output: '', error: '');

    for (final group in groups) {
      result = await _run(
        group,
        bail: bail,
        showOutput: showOutput,
        disableConcurrency: disableConcurrency,
        group: true,
      );

      if (result.exitCodeReason != ExitCode.success && bail) {
        return result;
      }
    }

    return result;
  }

  Future<CommandResult> run(
    List<Runnable> scripts, {
    required bool bail,
    bool disableConcurrency = false,
    bool showOutput = true,
  }) async {
    return _run(
      scripts.whereType<ScriptToRun>().toList(),
      bail: bail,
      showOutput: showOutput,
      disableConcurrency: disableConcurrency,
      group: false,
    );
  }

  Future<CommandResult> _run(
    List<ScriptToRun> scripts, {
    required bool bail,
    required bool showOutput,
    required bool group,
    required bool disableConcurrency,
  }) async {
    final stopwatch = Stopwatch()..start();

    final result = await _runScripts(
      scripts,
      bail: bail,
      showOutput: showOutput,
      group: group,
      disableConcurrency: disableConcurrency,
    );

    final time = (stopwatch..stop()).format();

    logger.info(darkGray.wrap('Finished in $time'));

    if (result.exitCodeReason != ExitCode.success) {
      return result;
    }

    return const CommandResult(exitCode: 0, output: '', error: '');
  }

  Future<CommandResult> _runScripts(
    List<ScriptToRun> scripts, {
    required bool bail,
    required bool showOutput,
    required bool group,
    required bool disableConcurrency,
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
        ({bool? showOutputOverride}) => bindings.runScript(
          execute,
          showOutput: switch (showOutputOverride ?? showOutput) {
            false => false,
            true => switch (script.runInParallel) {
              true => false,
              null || false => false,
            },
          },
          bail: script.bail,
        ),
      ));
    }

    if (group && !disableConcurrency) {
      final tasks = _group(pending);

      const count = 0;

      String label() {
        final counter = magenta.wrap('$count/${pending.length}')!;
        return 'Running $counter';
      }

      final done = logger.progress(label());
      await for (final (part, result) in tasks) {
        done.update(label());

        if (result.exitCodeReason != ExitCode.success && bail) {
          final label = part.label;

          if (label case final String label) {
            done.fail('Script $label failed');
          }
          break;
        }
      }

      done.complete();

      return const CommandResult(exitCode: 0, output: '', error: '');
    } else {
      logger.detail('Running ${pending.length} scripts');
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
          if (running.isEmpty) {
            waitForRunning?.complete();
          }
          controller.add((part, result));

          if (index == pending.length - 1) {
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
