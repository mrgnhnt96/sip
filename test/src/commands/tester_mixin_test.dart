import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/src/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  const success = CommandResult(exitCode: 0, output: 'output', error: 'error');
  final failure = CommandResult(
    exitCode: ExitCode.config.code,
    output: 'output',
    error: 'error',
  );

  group(TesterMixin, () {
    late _Tester tester;
    late FileSystem fs;
    late Bindings bindings;
    late Logger logger;

    setUp(() {
      bindings = _MockBindings();
      logger = _MockLogger();

      fs = MemoryFileSystem.test();

      tester = const _Tester();
    });

    @isTest
    void test(String description, FutureOr<void> Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        bindings: () => bindings,
        logger: () => logger,
      );
    }

    group('#packageRootFor', () {
      group('successfully returns the path when', () {
        test('a dir path is provided', () async {
          final expected = {
            'test': '.',
            'test/': '.',
            'test/sub': '.',
            'test/sub/': '.',
            'lib': '.',
            'lib/': '.',
            'lib/src': '.',
            'lib/src/': '.',
          };

          for (final entry in expected.entries) {
            final result = tester.packageRootFor(entry.key);
            expect(result, entry.value);
          }
        });

        test('a file path is provided', () {
          final expected = {
            'test/some_test.dart': '.',
            'test/sub/some_test.dart': '.',
            'lib/some_file.dart': '.',
            'lib/src/some_file.dart': '.',
          };

          for (final entry in expected.entries) {
            final result = tester.packageRootFor(entry.key);
            expect(result, entry.value);
          }
        });

        test('when nested in a sub package', () {
          final expected = {
            'packages/ui/test': 'packages/ui',
            'packages/ui/lib': 'packages/ui',
            'packages/ui/lib/some_file.dart': 'packages/ui',
            'packages/ui/test/some_file.dart': 'packages/ui',
          };

          for (final entry in expected.entries) {
            final result = tester.packageRootFor(entry.key);
            expect(result, entry.value);
          }
        });
      });
    });

    group('#runCommands', () {
      test('should run commands', () async {
        when(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).thenAnswer((_) => Future.value(success));

        final commands = [ScriptToRun('something', workingDirectory: '.')];

        final results = await tester.runCommands(
          commands,
          bail: false,
          showOutput: false,
        );

        expect(results, ExitCode.success);
      });

      test('should bail when first fails', () async {
        when(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).thenAnswer((_) => Future.value(failure));

        final commands = [
          ScriptToRun('something', workingDirectory: '.'),
          ScriptToRun('else', workingDirectory: '.'),
        ];

        final results = await tester.runCommands(
          commands,
          bail: true,
          showOutput: false,
        );

        expect(results.code, failure.exitCode);
        verify(
          () => bindings.runScriptWithOutput(
            any(),
            onOutput: any(named: 'onOutput'),
            bail: any(named: 'bail'),
          ),
        ).called(2);
      });

      group('should run all commands', () {
        test('concurrently', () async {
          when(
            () => bindings.runScriptWithOutput(
              any(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).thenAnswer((_) => Future.value(success));

          final commands = [
            ScriptToRun('something', workingDirectory: '.'),
            ScriptToRun('else', workingDirectory: '.'),
          ];

          final results = await tester.runCommands(
            commands,
            bail: false,
            showOutput: true,
          );

          expect(results, ExitCode.success);
          verify(
            () => bindings.runScriptWithOutput(
              any(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).called(2);
        });

        test('not concurrently', () async {
          when(
            () => bindings.runScriptWithOutput(
              any(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).thenAnswer((_) => Future.value(success));

          final commands = [
            ScriptToRun('something', workingDirectory: '.'),
            ScriptToRun('else', workingDirectory: '.'),
          ];

          final results = await tester.runCommands(
            commands,
            bail: false,
            showOutput: false,
          );

          expect(results, ExitCode.success);
          verify(
            () => bindings.runScriptWithOutput(
              any(),
              onOutput: any(named: 'onOutput'),
              bail: any(named: 'bail'),
            ),
          ).called(2);
        });
      });
    });

    group('#cleanUp', () {
      test('should delete optimized files', () {
        const path = 'test/${TesterMixin.optimizedTestBasename}';
        fs.file(path).createSync(recursive: true);

        tester.cleanUpOptimizedFiles([path]);

        expect(fs.file(path).existsSync(), isFalse);
      });

      test('should not delete non optimized file', () {
        fs.file('test/other.dart').createSync(recursive: true);

        tester.cleanUpOptimizedFiles(['test/other.dart']);

        expect(fs.file('test/other.dart').existsSync(), isTrue);
      });
    });
  });
}

class _Tester extends TesterMixin {
  const _Tester();
}

class _MockBindings extends Mock implements Bindings {}

class _MockLogger extends Mock implements Logger {
  @override
  Progress progress(String message, {ProgressOptions? options}) {
    return _MockProgress();
  }

  @override
  Level get level => Level.quiet;
}

class _MockProgress extends Mock implements Progress {}
