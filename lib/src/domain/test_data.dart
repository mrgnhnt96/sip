import 'dart:io' as io;

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/time.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/time.dart';

class TestData {
  TestData();

  int get passing => _success.length;
  int get failing => _failure.length;
  int get skipped => _skipped.length;

  bool? _isCi;

  Object? failure;

  final _data = <int, TestData>{};

  final _success = <TestOutput>[];
  final _failure = <TestOutput>[];
  final _skipped = <TestOutput>[];

  bool get hasTerminal {
    try {
      return io.stdout.hasTerminal;
    } catch (e) {
      return false;
    }
  }

  String? _previous;
  TestOutput? _last;

  /// Parses the output of a dart test
  /// - updates the test data
  /// - prints the test data
  void parseDart(Runnable script, String output) {
    final data = _data[script.hashCode] ??= TestData();

    var message = [?data._previous, output].join('\n');

    if (output.contains('::group::') && !output.contains('::endgroup::')) {
      data._previous = output;
      return;
    }

    final isCi = _isCi ??=
        output.contains('::group::') && output.contains('::endgroup::');

    // successful CI test output
    if (output.startsWith('✅')) {
      final wasSuccess = message.contains('✅');
      final wasSkipped = message.contains('(skipped)');

      message = message.substring(1).trim();
      final [path, ...test] = message.split(' ');
      final output = TestOutput(path: path, test: test.join(' '), error: null);
      if (wasSkipped) {
        _skipped.add(output);
      } else if (wasSuccess) {
        _success.add(output);
      }

      data
        .._previous = null
        .._last = output;
    } else if (isCi) {
      message = message
          .replaceAll('::group::', '')
          .replaceAll('::endgroup::', '');

      if (!RegExp('^[✅❌]').hasMatch(message)) {
        if (data._last case final last?) {
          last.error = [?last.error?.trim(), message.trim()].join('\n');
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

      if (test case ['loading', ...]) {
        return;
      }

      final output = TestOutput(path: path, test: test.join(' '), error: error);

      if (wasSkipped) {
        _skipped.add(output);
      } else if (wasSuccess) {
        _success.add(output);
      } else if (wasFailure) {
        _failure.add(output);
      }
      data
        .._previous = null
        .._last = output;
    } else {
      if (!RegExp(r'^\d{2,}:\d{2,}').hasMatch(message)) {
        if (data._last case final last?) {
          last.error = [?last.error?.trim(), message.trim()].join('\n');
          return;
        }
      }

      final path = RegExp(r'(\S*\.dart)').firstMatch(message)?.group(1);
      final description = RegExp(r'\.dart (.*)').firstMatch(message)?.group(1);

      if (path == null || description == null) {
        return;
      }

      final error = switch (message.split(description)) {
        [_, final error] => switch (error.trim()) {
          final String error when error.isNotEmpty => error,
          _ => null,
        },
        _ => null,
      };

      final output = TestOutput(
        path: path,
        test: description,
        error: error,
        passing: RegExp(r'\+(\d+)').firstMatch(message)?.group(1),
        failing: RegExp(r'-(\d+)').firstMatch(message)?.group(1),
        skipped: RegExp(r'~(\d+)').firstMatch(message)?.group(1),
        previous: data._last,
      );

      final (:failed, :passed, :skipped) = output.results;

      if (!failed && !passed && !skipped) {
        return;
      }

      if (output.matchesLast) {
        return;
      }

      if (passed) {
        _success.add(output);
      } else if (failed) {
        _failure.add(output);
      } else if (skipped) {
        _skipped.add(output);
      }

      data._last = output;
      _print(output);
    }
  }

  /// Parses the output of a flutter test
  /// - updates the test data
  /// - prints the test data
  void parseFlutter(Runnable script, String output) {
    final data = _data[script.hashCode] ??= TestData();

    _data[script.hashCode] = data;
    data._previous = output;
  }

  void _print(TestOutput output) {
    Iterable<String?> items() sync* {
      if (time.get(TimeKey.test) case final stopwatch) {
        final minutes = stopwatch.elapsed.inMinutes;
        final seconds = stopwatch.elapsed.inSeconds % 60;
        final min = '$minutes'.padLeft(2, '0');
        final sec = '$seconds'.padLeft(2, '0');
        yield '$min:$sec';
      }

      if (hasTerminal) {
        // move the cursor to the start of the line
        yield '\x1B[0G';
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
        yield darkGray.wrap('$path |');
        yield white.wrap(test);
      }

      if (hasTerminal) {
        // clear the rest of the line
        yield '\x1B[K';
      }

      if (output case TestOutput(didFail: true, :final String error)) {
        if (error.trim() case final error when error.isNotEmpty) {
          yield '\n';
          yield error;
        }

        if (hasTerminal) {
          yield '\n';
        }
      }

      if (!hasTerminal) {
        yield '\n';
      }
    }

    logger.write(items().join(' '));
  }

  void printResults() {
    final buf = StringBuffer();

    if (_isCi case true) {
      if (failure case final Object e) {
        buf
          ..writeln('::group::❌ Failed to finish')
          ..writeln(e)
          ..writeln('::endgroup::');
      }

      buf.writeln('Tests Summary ✅ $passing ❌ $failing ⚠️ $skipped');
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
      if (failure case final Object e) {
        buf
          ..writeln('❌ Failed to finish')
          ..writeln('$e'.trim())
          ..writeln();
      }

      buf.writeln('✅ $passing ❌ $failing ⚠️ $skipped');
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

    final passed = passing != null && previous?.passing != passing;
    final failed = failing != null && previous?.failing != failing;
    final skip = skipped != null && previous?.skipped != skipped;

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
    return '$path | $test';
  }
}
