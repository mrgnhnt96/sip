import 'dart:async';
import 'dart:io' as io;

import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/script_runner.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  for (final scenario in [
    (name: 'stderr failure', rows: 5, columns: 20, label: 'long/package/path'),
    (name: 'stdout failure', rows: 5, columns: 20, label: 'long/package/path'),
    (name: 'rows that fit', rows: 2, columns: 80, label: 'package'),
    (name: 'too many rows', rows: 5, columns: 80, label: 'package'),
    (
      name: 'wrapped paths',
      rows: 2,
      columns: 12,
      label: 'very/long/package/path/example',
    ),
  ]) {
    final output = <String>[];
    final logger = _MockLogger();
    final failure = scenario.name.endsWith('failure');
    const details =
        'Dependency resolution failed for a very long package path.\n'
        'The full error must be preserved, including this last line.';
    final bindings = _DelayedBindings(
      firstResult: failure
          ? CommandResult(
              exitCode: 1,
              output: scenario.name == 'stdout failure' ? details : '',
              error: scenario.name == 'stderr failure' ? details : '',
            )
          : const CommandResult(exitCode: 0, output: '', error: ''),
    );
    var earlyOutput = '';
    final stdout = _MockStdout();

    testScoped(
      'concurrent progress handles ${scenario.name}',
      () async {
        when(() => logger.level).thenReturn(Level.info);
        when(() => logger.write(any())).thenAnswer((call) {
          output.add(call.positionalArguments.single as String);
        });
        when(() => stdout.hasTerminal).thenReturn(true);
        when(() => stdout.supportsAnsiEscapes).thenReturn(true);
        when(() => stdout.terminalColumns).thenReturn(scenario.columns);
        when(() => stdout.terminalLines).thenReturn(5);

        await io.IOOverrides.runZoned(() async {
          final run = const ScriptRunner().run(
            [
              for (var i = 0; i < scenario.rows; i++)
                ScriptToRun(
                  'command$i',
                  label: '${scenario.label}$i',
                  workingDirectory: '/',
                  runInParallel: true,
                ),
            ],
            bail: false,
            logTime: false,
          );
          await Future<void>.delayed(const Duration(milliseconds: 260));
          bindings.firstFinished.complete();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          earlyOutput = output.join();
          if (scenario.name == 'too many rows') {
            expect(output.last, contains('1/5 done'));
            expect(output.last, contains('package1'));
          } else if (!failure) {
            expect(output.last, contains('✓'));
          }
          bindings.finished.complete();
          await run;
        }, stdout: () => stdout);

        if (failure) {
          expect(earlyOutput, contains('✗ ${scenario.label}0'));
          for (final line in details.split('\n')) {
            expect(earlyOutput, contains(line));
            expect(line.allMatches(output.join()), hasLength(1));
          }
          expect(output.last, isNot(contains('Dependency resolution')));
          final errorIndex = output.indexWhere(
            (frame) => frame.contains('Dependency resolution'),
          );
          expect(
            output[errorIndex + 1],
            isNot(matches(RegExp(r'\x1b\[\d+A'))),
            reason: 'Redraws must start below the permanent error block',
          );
        }
        expect(output.length, greaterThan(1));
        expect(output.first, contains('⠋'));
        for (final frame in output.take(output.length - 1)) {
          if (failure && frame.contains('Dependency resolution')) continue;
          final plain = frame.replaceAll(RegExp(r'\x1b\[[0-9;]*[A-Za-z]'), '');
          final lines = plain.split('\n')..removeLast();
          expect(lines.length, lessThan(5));
          for (final line in lines) {
            expect(
              line.replaceAll('\r', '').length,
              lessThan(scenario.columns),
            );
          }
        }
        if (scenario.name == 'wrapped paths') {
          expect(output.first, contains('…'));
          expect('\n'.allMatches(output.first), hasLength(scenario.rows));
        }
        expect(output.last, isNot(contains('⠋')));
        expect(
          '✓'.allMatches(output.last),
          hasLength(scenario.rows - (failure ? 1 : 0)),
        );
      },
      fileSystem: MemoryFileSystem.new,
      logger: () => logger,
      bindings: () => bindings,
    );
  }
}

class _MockLogger extends Mock implements Logger {}

class _MockStdout extends Mock implements io.Stdout {}

class _DelayedBindings extends Bindings {
  _DelayedBindings({required this.firstResult});

  final CommandResult firstResult;
  final firstFinished = Completer<void>();
  final finished = Completer<void>();

  @override
  Future<CommandResult> runScript(
    String script, {
    required bool showOutput,
    bool bail = false,
  }) async {
    await (script.contains('command0') ? firstFinished : finished).future;
    return script.contains('command0')
        ? firstResult
        : const CommandResult(exitCode: 0, output: '', error: '');
  }
}
