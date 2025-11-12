// ignore_for_file: avoid_redundant_argument_values

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/commands/script_run_command.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/script_runner.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:test/test.dart';

import '../../../utils/test_scoped.dart';

void main() {
  group('concurrency groups test', () {
    late FileSystem fs;
    late Bindings bindings;
    late ScriptRunner scriptRunner;

    setUpAll(() {
      registerFallbackValue(const ConcurrentBreak() as Runnable);
    });

    setUp(() {
      bindings = _MockBindings();
      scriptRunner = _MockScriptRunner();
      fs = MemoryFileSystem.test();

      when(
        () => bindings.runScript(captureAny(), showOutput: false),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );

      when(
        () => scriptRunner.run(any(), disableConcurrency: false, bail: false),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );
      when(
        () => scriptRunner.run(any(), disableConcurrency: false, bail: false),
      ).thenAnswer(
        (_) async => const CommandResult(exitCode: 0, output: '', error: ''),
      );

      final cwd = fs.directory(path.join('packages', 'sip'))
        ..createSync(recursive: true);
      fs.currentDirectory = cwd;
    });

    ScriptRunCommand setupScripts() {
      final input = io.File(
        path.joinAll([
          'test',
          'e2e',
          'run',
          'concurrency_groups',
          'inputs',
          'scripts.yaml',
        ]),
      ).readAsStringSync();

      fs.file(ScriptsYaml.fileName)
        ..createSync(recursive: true)
        ..writeAsStringSync(input);
      fs.file(PubspecYaml.fileName)
        ..createSync(recursive: true)
        ..writeAsStringSync('');

      return const ScriptRunCommand();
    }

    @isTest
    void test(String description, Future<void> Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        bindings: () => bindings,
        scriptRunner: () => scriptRunner,
      );
    }

    test(
      'should run concurrent groups and isolate non-concurrent groups',
      () async {
        final command = setupScripts();

        await command.run(['combined']);

        final [results] = verify(
          () => scriptRunner.run(
            captureAny(),
            disableConcurrency: false,
            bail: false,
            showOutput: true,
          ),
        ).captured;

        expect(results, hasLength(10));

        for (final result in results as List<Runnable>) {
          switch (result) {
            case ScriptToRun(exe: 'wait 1', runInParallel: true):
            case ScriptToRun(exe: 'wait 2', runInParallel: true):
            case ScriptToRun(exe: 'wait 3', runInParallel: true):
            case ConcurrentBreak():
            case ScriptToRun(exe: 'wait 4', runInParallel: true):
            case ScriptToRun(exe: 'wait 5', runInParallel: true):
            case ScriptToRun(exe: 'echo 6', runInParallel: false):
            case ScriptToRun(exe: 'wait 1; echo 1', runInParallel: false):
            case ScriptToRun(exe: 'wait 1; echo 2', runInParallel: false):
            case ScriptToRun(exe: 'wait 1; echo 3', runInParallel: false):
              continue;
            default:
              fail('Unexpected result: $result');
          }
        }
      },
    );

    test('should run concurrent group', () async {
      final command = setupScripts();

      await command.run(['all_concurrent']);

      final [results] = verify(
        () => scriptRunner.run(
          captureAny(),
          disableConcurrency: false,
          bail: false,
        ),
      ).captured;

      expect(results, hasLength(3));

      for (final result in results as List<Runnable>) {
        switch (result) {
          case ScriptToRun(exe: 'wait 1', runInParallel: true):
          case ScriptToRun(exe: 'wait 2', runInParallel: true):
          case ScriptToRun(exe: 'wait 3', runInParallel: true):
            continue;
          default:
            fail('Unexpected result: $result');
        }
      }
    });

    test('should run non-concurrent group', () async {
      final command = setupScripts();

      await command.run(['no_concurrent']);

      final [results] = verify(
        () => scriptRunner.run(
          captureAny(),
          showOutput: true,
          disableConcurrency: false,
          bail: false,
        ),
      ).captured;

      expect(results, hasLength(3));

      for (final result in results as List<Runnable>) {
        switch (result) {
          case ScriptToRun(exe: 'wait 1', runInParallel: false):
          case ScriptToRun(exe: 'wait 1; echo 1', runInParallel: false):
          case ScriptToRun(exe: 'wait 1; echo 2', runInParallel: false):
          case ScriptToRun(exe: 'wait 1; echo 3', runInParallel: false):
            continue;
          default:
            fail('Unexpected result: $result');
        }
      }
    });

    test('should run partial-concurrent group', () async {
      final command = setupScripts();

      await command.run(['partial_concurrent']);

      final [results] = verify(
        () => scriptRunner.run(
          captureAny(),
          showOutput: true,
          disableConcurrency: false,
          bail: false,
        ),
      ).captured;

      expect(results, hasLength(3));

      for (final result in results as List<Runnable>) {
        switch (result) {
          case ScriptToRun(exe: 'wait 4', runInParallel: true):
          case ScriptToRun(exe: 'wait 5', runInParallel: true):
          case ScriptToRun(exe: 'echo 6', runInParallel: false):
            continue;
          default:
            fail('Unexpected result: $result');
        }
      }
    });

    test('should combine groups when leading with concurrency', () async {
      final command = setupScripts();

      await command.run(['combined_concurrent']);

      final [results] = verify(
        () => scriptRunner.run(
          captureAny(),
          disableConcurrency: false,
          bail: false,
        ),
      ).captured;

      expect(results, hasLength(7));

      for (final result in results as List<Runnable>) {
        switch (result) {
          case ScriptToRun(exe: 'wait 1', runInParallel: true):
          case ScriptToRun(exe: 'wait 2', runInParallel: true):
          case ScriptToRun(exe: 'wait 3', runInParallel: true):
          case ConcurrentBreak():
          case ScriptToRun(exe: 'wait 4', runInParallel: true):
          case ScriptToRun(exe: 'wait 5', runInParallel: true):
          case ScriptToRun(exe: 'echo 6', runInParallel: false):
            continue;
          default:
            fail('Unexpected result: $result');
        }
      }
    });

    test('should combine all groups when leading with concurrency', () async {
      final command = setupScripts();

      await command.run(['everything_concurrent']);

      final [results] = verify(
        () => scriptRunner.run(
          captureAny(),
          disableConcurrency: false,
          bail: false,
        ),
      ).captured;

      expect(results, hasLength(10));

      for (final result in results as List<Runnable>) {
        switch (result) {
          case ScriptToRun(exe: 'wait 1', runInParallel: true):
          case ScriptToRun(exe: 'wait 2', runInParallel: true):
          case ScriptToRun(exe: 'wait 3', runInParallel: true):
          case ConcurrentBreak():
          case ScriptToRun(exe: 'wait 4', runInParallel: true):
          case ScriptToRun(exe: 'wait 5', runInParallel: true):
          case ScriptToRun(exe: 'echo 6', runInParallel: false):
          case ScriptToRun(exe: 'wait 1; echo 1', runInParallel: false):
          case ScriptToRun(exe: 'wait 1; echo 2', runInParallel: false):
          case ScriptToRun(exe: 'wait 1; echo 3', runInParallel: false):
            continue;
          default:
            fail('Unexpected result: $result');
        }
      }
    });
  });
}

class _MockBindings extends Mock implements Bindings {}

class _MockScriptRunner extends Mock implements ScriptRunner {}
