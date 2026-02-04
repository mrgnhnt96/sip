import 'dart:io' as io;

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/time.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/time.dart';
import 'package:sip_cli/src/utils/constants.dart';
import 'package:sip_cli/src/utils/is_ci.dart';

class TestData {
  TestData();

  int get passing => _success.length;
  int get failing => _failure.length;
  int get skipped => _skipped.length;

  ({int passing, int failing, int skipped}) get snapshot {
    return (passing: passing, failing: failing, skipped: skipped);
  }

  Object? _error;

  void addError(Runnable? script, Object error) {
    if (script != null) {
      _data[script.hashCode]?._error = error;
    } else {
      _error = error;
    }
  }

  List<Object> get allFailures {
    Iterable<Object> items(TestData data) sync* {
      if (data._error case final Object e) {
        yield e;
      }

      for (final data in data._data.values) {
        if (data._error case final Object e) {
          yield e;
        }
      }
    }

    return items(this).toList();
  }

  final _data = <int, TestData>{};

  final _success = <TestOutput>[];
  final _failure = <TestOutput>[];
  final _skipped = <TestOutput>[];

  bool get hasTerminal {
    if (Env.sipCliScript.isSet) {
      return true;
    }

    try {
      return io.stdout.hasTerminal;
    } catch (e) {
      // do nothing
    }

    return false;
  }

  String? _previous;
  TestOutput? _last;

  void parseCi(Runnable script, String output) {
    final data = _data[script.hashCode] ??= TestData();

    var message = [?data._previous, output].join('\n');

    message = message
        .replaceAll('::group::', '')
        .replaceAll('::endgroup::', '');

    if (output.contains('::group::') && !output.contains('::endgroup::')) {
      data._previous = output;
      return;
    }

    // successful CI test output
    if (output.startsWith('✅')) {
      final wasSuccess = message.contains('✅');
      final wasSkipped = message.contains('(skipped)');

      message = message.substring(1).trim();
      final [rawPath, ...test] = message.split(' ');
      final path = switch (rawPath) {
        final String path when fs.path.isRelative(path) => path,
        final String path => fs.path.relative(path),
      };

      final output = TestOutput(path: path, test: test.join(' '), error: null);
      if (wasSkipped) {
        _skipped.add(output);
      } else if (wasSuccess) {
        _success.add(output);
      }

      _print(output);

      data
        .._previous = null
        .._last = output;
      return;
    }

    if (!RegExp('^[✅❌]').hasMatch(message)) {
      if (data._last case final last?) {
        last.error = [?last.error?.trim(), message.trim()].join('\n');
        data._previous = null;
        return;
      }
    }

    final wasSuccess = message.contains('✅');
    final wasFailure = message.contains('❌');
    final wasSkipped = message.contains('(skipped)');

    String? error;
    if (wasFailure) {
      switch (message.split(RegExp(r'\(failed\)$', multiLine: true))) {
        case [final info, final e]:
          error = e.trim();
          message = info.trim();
      }
    }
    final [path, ...test] = message.substring(1).trim().split(' ');

    if (path == 'loading') {
      data._previous = null;
      return;
    }

    final out = TestOutput(path: path, test: test.join(' '), error: error);

    if (wasSkipped) {
      _skipped.add(out);
    } else if (wasSuccess) {
      _success.add(out);
    } else if (wasFailure) {
      _failure.add(out);
    }

    logger.detail('$path | $test');
    _print(out);

    data
      .._previous = null
      .._last = out;
  }

  /// Parses the output of a dart test (always CI format)
  /// - updates the test data
  /// - prints the test data
  void parse(Runnable script, String output) {
    if (time.get(TimeKey.test) case final stopwatch) {
      final minutes = stopwatch.elapsed.inMinutes;
      final seconds = stopwatch.elapsed.inSeconds % 60;
      final min = '$minutes'.padLeft(2, '0');
      final sec = '$seconds'.padLeft(2, '0');
      logger.detail('$min:$sec ${output.trim()}');
    }

    parseCi(script, output);
  }

  void _print(TestOutput output) {
    if (isCi()) return;

    Iterable<String?> items() sync* {
      if (hasTerminal) {
        // move the cursor to the start of the line
        yield '\x1B[2K\x1B[0G';
      }

      if (time.get(TimeKey.test) case final stopwatch) {
        final minutes = stopwatch.elapsed.inMinutes;
        final seconds = stopwatch.elapsed.inSeconds % 60;
        final min = '$minutes'.padLeft(2, '0');
        final sec = '$seconds'.padLeft(2, '0');
        yield cyan.wrap('$min:$sec');
      }

      if (passing > 0) {
        yield green.wrap('+$passing');
      }

      if (failing > 0) {
        yield red.wrap('-$failing');
      }

      if (skipped > 0) {
        yield yellow.wrap('~$skipped');
      }

      if (output case TestOutput(:final path, :final test)) {
        yield darkGray.wrap('$path │');
        yield white.wrap(test);
      }

      if (hasTerminal) {
        // clear the rest of the line
        yield '\x1B[K';
      }

      if (output case TestOutput(didFail: true, :final String error)) {
        if (args['omit-errors'] case null || false) {
          if (error.trim() case final error when error.isNotEmpty) {
            yield '\n';

            final lines = error.split('\n');
            for (final line in lines) {
              yield lightRed.wrap('│');
              yield '${darkGray.wrap(resetAll.wrap(line))}\n';
            }
          }
        }

        if (hasTerminal) {
          yield '\n';
        }
      }

      if (!hasTerminal) {
        yield '\n';
      }
    }

    final out = items().join(' ');

    if (out.split('\n').length > 1 || !hasTerminal) {
      logger.write(out);
    } else {
      logger
        ..detail('')
        // disable wrap around mode
        ..write('\x1b[?7l')
        ..write(out)
        // enable wrap around mode
        ..write('\x1b[?7h');
    }
  }

  void printResults() {
    final buf = StringBuffer();

    if (isCi()) {
      buf.writeln();

      if (allFailures case final errors when errors.isNotEmpty) {
        buf.writeln('::group::❌ Failed to finish');
        for (final error in errors) {
          buf.writeln(error);
        }
        buf.writeln('::endgroup::');
      }

      buf.writeln('Results: ✅ $passing ❌ $failing ⚠️ $skipped');
      if (_success.isNotEmpty) {
        buf.writeln('::group::✅ Passing: $passing');
        for (final success in _success) {
          buf.writeln('✅ $success');
        }
        buf.writeln('::endgroup::\n');
      }

      if (_failure.isNotEmpty) {
        buf.writeln('::group::❌ Failing: $failing');
        for (final failure in _failure) {
          buf.writeln('❌ $failure');
        }
        buf.writeln('::endgroup::\n');
      }

      if (_skipped.isNotEmpty) {
        buf.writeln('::group::⚠️ Skipped: $skipped');
        for (final skipped in _skipped) {
          buf.writeln('⚠️ $skipped');
        }
        buf.writeln('::endgroup::\n');
      }
    } else {
      if (!hasTerminal) {
        buf.writeln();
      } else {
        // move the cursor to the start of the line
        buf.write('\x1B[0G');
      }

      buf.write('Results: ✅ $passing ❌ $failing ⚠️  $skipped');
      if (hasTerminal) {
        // clear the rest of the line
        buf.write('\x1B[K');
      } else {
        buf.writeln();
      }

      if (_error case final Object e) {
        buf
          ..writeln('❌ Failed to finish')
          ..writeln('$e'.trim())
          ..writeln();
      }
    }

    logger.write(buf.toString());
  }
}

class TestOutput {
  TestOutput({
    required this.path,
    required String test,
    required this.error,
    this.previous,
    String? passing,
    String? failing,
    String? skipped,
  }) : test = test.trim(),
       passing = int.tryParse(passing ?? ''),
       failing = int.tryParse(failing ?? ''),
       skipped = int.tryParse(skipped ?? '');

  final String path;
  final String test;
  String? error;

  final int? passing;
  final int? failing;
  final int? skipped;

  final TestOutput? previous;

  ({bool passed, bool failed, bool skipped}) get results {
    if (previous == null) {
      return (
        passed: switch (passing) {
          null || == 0 => false,
          _ => true,
        },
        failed: switch (failing) {
          null || == 0 => false,
          _ => true,
        },
        skipped: switch (skipped) {
          null || == 0 => false,
          _ => true,
        },
      );
    }

    // Only mark as changed if the count actually increased (not just changed)
    // This prevents false positives when counts go from null to 0, or when
    // they stay the same but we're comparing different objects
    final prevPassing = previous?.passing ?? 0;
    final prevFailing = previous?.failing ?? 0;
    final prevSkipped = previous?.skipped ?? 0;

    final passed = switch (passing) {
      null || == 0 => false,
      final passing => passing > prevPassing,
    };
    final failed = switch (failing) {
      null || == 0 => false,
      final failing => failing > prevFailing,
    };
    final skip = switch (skipped) {
      null || == 0 => false,
      final skipped => skipped > prevSkipped,
    };

    return (passed: passed, failed: failed, skipped: skip);
  }

  bool get didFail => results.failed;
  bool get didPass => results.passed;
  bool get didSkip => results.skipped;

  bool get matchesLast {
    final previous = this.previous;
    if (previous == null) return false;

    if (path != previous.path) return false;
    if (!test.startsWith(previous.test)) return false;

    if (passing != previous.passing) return false;
    if (failing != previous.failing) return false;
    if (skipped != previous.skipped) return false;

    return true;
  }

  @override
  String toString() {
    Iterable<String?> items() sync* {
      yield darkGray.wrap('$path │');
      yield white.wrap(test);

      if (error case final String error) {
        if (args['omit-errors'] case null || false) {
          if (error.trim() case final error when error.isNotEmpty) {
            yield '\n';

            final lines = error.split('\n');
            for (final line in lines) {
              yield lightRed.wrap('│');
              yield '${darkGray.wrap(resetAll.wrap(line))}\n';
            }
          }
        }
      }
    }

    return items().join(' ');
  }
}
