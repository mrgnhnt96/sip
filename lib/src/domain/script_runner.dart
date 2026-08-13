// ignore_for_file: avoid_private_typedef_functions

import 'dart:async';
import 'dart:io' as io;

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
import 'package:sip_cli/src/utils/shell_script.dart';

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
    void Function(Runnable script, CommandResult result)? onScriptResult,
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
        onScriptResult: onScriptResult,
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
    void Function(Runnable script, CommandResult result)? onScriptResult,
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

      final variableBlock = switch (script.variables) {
        final map when map.isNotEmpty => [
          for (final MapEntry(:key, :value) in map.entries)
            ShellScript.setVariable(key, value),
        ].join(ShellScript.variableSeparator),
        _ => null,
      };

      final execute = ShellScript.joinCommands([
        ShellScript.changeDirectory(workingDirectory),
        ?variableBlock,
        script.exe,
      ]);

      pending.add((
        script,
        ({bool? showOutputOverride}) {
          logger.detail(execute);

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

    final results = <CommandResult>[];

    if (disableConcurrency) {
      logger.detail('Running ${pending.length} scripts sequentially');

      for (final (part, future) in pending) {
        if (showOutput) {
          logger.write('\n');
        }

        if (printLabels) {
          if (part case ScriptToRun(:final String label)) {
            final formatted = darkGray.wrap('--- $label ---');
            logger.info('$formatted');
          }
        }

        final result = await future();
        results.add(result);
        onScriptResult?.call(part, result);

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
        bail: bail,
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

      await for (final (part, taskResult) in tasks) {
        done?.update(label());
        count++;
        results.add(taskResult);
        onScriptResult?.call(part, taskResult);

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
    }

    final output = StringBuffer();
    final error = StringBuffer();

    var hasFailure = false;

    for (final result in results) {
      if (result.exitCodeReason != ExitCode.success) {
        hasFailure = true;
        output.write(result.output);
        error.write(result.error);
      }
    }

    if (hasFailure) {
      return CommandResult(
        exitCode: 1,
        output: output.toString(),
        error: error.toString(),
      );
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
    required bool bail,
  }) async* {
    if (pending.isEmpty) {
      throw Exception('Unexpected: No scripts to run');
    }

    final controller = StreamController<(ScriptToRun, CommandResult)>();

    Completer<void>? waitForRunning;
    final running = <ScriptToRun>[];

    final useLiveRows =
        io.stdout.hasTerminal && logger.level.index <= Level.info.index;

    Progress? done;
    ({String output, bool parallel})? last;
    void Function()? updateDone;
    _ConcurrentRows? liveRows;
    final rowIndexByPart = <ScriptToRun, int>{};

    void log(String output) {
      if (showOutput) {
        final formatted = darkGray.wrap('\n--- $output ---');
        logger.info(formatted);
        return;
      }

      done = logger.progress('${cyan.wrap(output)}');
    }

    // Tracks whether the for-loop has finished launching all tasks.
    // Parallel `.then()` callbacks are microtasks — they cannot fire until
    // the synchronous loop body completes, so reading this flag inside a
    // callback is safe.
    var allLaunched = false;

    // Every task is launched before the first result reaches the consumer --
    // this loop runs to completion and only then is `controller.stream`
    // yielded. So a consumer that stops reading on failure cannot stop
    // anything: bail has to be enforced here, where the launching happens.
    var bailed = false;

    for (final (index, (part, future)) in pending.indexed) {
      if (bailed) break;

      if (printLabels) {
        if (part case ScriptToRun(:final String label)) {
          final current = (
            output: label,
            parallel: part.runInParallel ?? false,
          );

          if (current.parallel) {
            // Parallel scripts are listed one per row rather than merged
            // into a single shared spinner; each animates independently
            // until it finishes (see the `.then()` below).
            if (last?.parallel == false) {
              done?.complete();
              done = null;
            }

            if (useLiveRows) {
              liveRows ??= _ConcurrentRows(logger);
              rowIndexByPart[part] = liveRows!.addRow(current.output);
            }
          } else if (last?.parallel case true) {
            updateDone = () => log(current.output);
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

        final stopwatch = Stopwatch()..start();

        future(showOutputOverride: false).then((result) {
          stopwatch.stop();
          running.remove(part);

          if (printLabels) {
            if (part case ScriptToRun(:final String label)) {
              final success = result.exitCodeReason == ExitCode.success;
              final time = _formatElapsed(stopwatch.elapsed);

              final detailLines = <String>[];
              if (!success) {
                final details = switch (result.error.trim()) {
                  final error when error.isNotEmpty => error,
                  _ => result.output.trim(),
                };

                if (details.isNotEmpty) {
                  detailLines.addAll(
                    details.split('\n').map((line) => '  $line'),
                  );
                }
              }

              final row = liveRows == null ? null : rowIndexByPart[part];

              if (row != null) {
                liveRows!.complete(
                  row,
                  success: success,
                  time: time,
                  details: detailLines,
                );
              } else {
                final icon = success ? lightGreen.wrap('✓') : red.wrap('✗');
                logger.info('$icon $label ${darkGray.wrap('($time)')}');

                for (final line in detailLines) {
                  logger.info(darkGray.wrap(line));
                }
              }
            }
          }

          if (bail && result.exitCodeReason != ExitCode.success) {
            bailed = true;
          }

          controller.add((part, result));

          if (running.isEmpty) {
            waitForRunning?.complete();

            liveRows?.dispose();
            liveRows = null;
            rowIndexByPart.clear();

            if (allLaunched) {
              controller.close().ignore();
            }
          }
        }).ignore();
      } else {
        if (waitForRunning case final completer?) {
          await completer.future;
          waitForRunning = null;
          updateDone?.call();
        }

        final result = await future();

        final shouldBail = switch (part) {
          ScriptToRun(bail: true) => true,
          _ => bail,
        };

        if (shouldBail && result.exitCodeReason != ExitCode.success) {
          bailed = true;
        }

        controller.add((part, result));

        if (bailed || index == pending.length - 1) {
          controller.close().ignore();
        }
      }
    }

    allLaunched = true;

    // If all tasks were parallel and all completed during an earlier `await`
    // (e.g. mixed parallel + sequential groups), the controller may still be
    // open. Close it now.
    if (running.isEmpty && !controller.isClosed) {
      controller.close().ignore();
    }

    if (waitForRunning case final completer?) {
      completer.future.then((_) {
        done?.complete();
      }).ignore();
    }

    yield* controller.stream;
  }

  static String _formatElapsed(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    final formatted = switch (ms) {
      < 100 => '${ms}ms',
      _ => '${(ms / 1000).toStringAsFixed(1)}s',
    };
    return formatted;
  }
}

/// Renders a batch of concurrently-running scripts as one animated row per
/// script, redrawing all rows in place on each tick.
///
/// Each row is either spinning (still running) or frozen with its final
/// ✓/✗ and elapsed time. Rows can only be appended, never removed, so the
/// cursor math in [_render] (move up by the previously-rendered physical
/// line count, accounting for terminal-width wrapping) stays correct
/// across ticks.
class _ConcurrentRows {
  _ConcurrentRows(this._logger);

  static const _frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

  final Logger _logger;
  final List<_ConcurrentRow> _rows = [];
  Timer? _timer;
  var _frame = 0;
  var _rendered = 0;

  int addRow(String label) {
    final index = _rows.length;
    _rows.add(_ConcurrentRow(label));
    _timer ??= Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _render(),
    );
    return index;
  }

  void complete(
    int index, {
    required bool success,
    required String time,
    List<String> details = const [],
  }) {
    _rows[index]
      ..done = true
      ..success = success
      ..time = time
      ..details = details;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _render();
  }

  void _render() {
    // A logical row's content can be wider than the terminal, in which case
    // the terminal itself wraps it onto extra physical lines the cursor
    // math below doesn't know about unless it's accounted for here.
    final columns = io.stdout.hasTerminal ? io.stdout.terminalColumns : 80;
    final width = columns > 1 ? columns - 1 : 1;

    final buffer = StringBuffer();

    if (_rendered > 0) {
      buffer.write('\x1b[${_rendered}A');
    }

    var lineCount = 0;

    void writeContent(String content) {
      for (final physicalLine in _wrapVisible(content, width)) {
        buffer
          ..write('\x1b[2K\r')
          ..write(physicalLine)
          ..write('\n');
        lineCount++;
      }
    }

    for (final row in _rows) {
      if (row case _ConcurrentRow(done: true, :final success?, :final time?)) {
        final icon = success ? lightGreen.wrap('✓') : red.wrap('✗');
        writeContent('$icon ${row.label} ${darkGray.wrap('($time)')}');
      } else {
        final char = _frames[_frame % _frames.length];
        writeContent('${lightGreen.wrap(char)} ${row.label}');
      }

      for (final line in row.details) {
        writeContent(darkGray.wrap(line) ?? line);
      }
    }

    _rendered = lineCount;
    _frame++;
    _logger.write(buffer.toString());
  }
}

/// Splits [text] into chunks no wider than [width] visible characters,
/// treating ANSI SGR escape sequences (`\x1b[...m`) as zero-width so color
/// codes don't get counted against the wrap width or split apart.
List<String> _wrapVisible(String text, int width) {
  if (width <= 0) return [text];

  final lines = <String>[];
  final current = StringBuffer();
  var visible = 0;
  var i = 0;

  while (i < text.length) {
    if (text[i] == '\x1b') {
      final end = text.indexOf('m', i);
      if (end != -1) {
        current.write(text.substring(i, end + 1));
        i = end + 1;
        continue;
      }
    }

    current.write(text[i]);
    visible++;
    i++;

    if (visible == width && i < text.length) {
      lines.add(current.toString());
      current.clear();
      visible = 0;
    }
  }

  lines.add(current.toString());
  return lines;
}

class _ConcurrentRow {
  _ConcurrentRow(this.label);

  final String label;
  bool done = false;
  bool? success;
  String? time;
  List<String> details = const [];
}
