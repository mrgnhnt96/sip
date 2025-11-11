import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/src/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/package_to_test.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/utils/determine_flutter_or_dart.dart';
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

    group('#testables', () {
      group('should return testable path when', () {
        test('test dir exists', () async {
          fs.file('pubspec.yaml').createSync();
          fs.directory('test').createSync();

          final result = tester.getTestDirs(
            ['pubspec.yaml'],
            isFlutterOnly: false,
            isDartOnly: false,
          );

          expect(result.$2, isNull);

          final (testables, testableTool) = result.$1!;

          expect(testables.length, 1);
          expect(testableTool.length, 1);
          expect(testables.length, testableTool.length);
        });

        test('dart only tests is enabled and is dart project', () {
          fs.file('pubspec.yaml').createSync();
          fs.file('pubspec.lock').createSync();
          fs.directory('test').createSync();

          final result = tester.getTestDirs(
            ['pubspec.yaml'],
            isFlutterOnly: false,
            isDartOnly: true,
          );

          expect(result.$2, isNull);

          final (testables, testableTool) = result.$1!;

          expect(testables.length, 1);
          expect(testableTool.length, 1);
          expect(testables.length, testableTool.length);
          expect(testableTool[testables.first]?.isDart, isTrue);
          expect(testableTool[testables.first]?.isFlutter, isFalse);
        });

        test('flutter only tests is enabled and is flutter project', () {
          fs.file('pubspec.yaml').createSync();
          fs.file('pubspec.lock')
            ..createSync()
            ..writeAsString('flutter');
          fs.directory('test').createSync();

          final result = tester.getTestDirs(
            ['pubspec.yaml'],
            isFlutterOnly: true,
            isDartOnly: false,
          );

          expect(result.$2, isNull);

          final (testables, testableTool) = result.$1!;

          expect(testables.length, 1);
          expect(testableTool.length, 1);
          expect(testables.length, testableTool.length);
          expect(testableTool[testables.first]?.isDart, isFalse);
          expect(testableTool[testables.first]?.isFlutter, isTrue);
        });
      });

      group('should not return testable path when', () {
        test('test dir does not exists', () async {
          fs.file('pubspec.yaml').createSync();

          final (tests, exitCode) = tester.getTestDirs(
            ['pubspec.yaml'],
            isFlutterOnly: false,
            isDartOnly: false,
          );

          expect(tests, isNull);
          expect(exitCode, isNotNull);
          expect(exitCode, isA<ExitCode>());
        });

        test('dart only tests is enabled and is flutter project', () {
          fs.file('pubspec.yaml').createSync();
          fs.file('pubspec.lock')
            ..createSync()
            ..writeAsString('flutter');

          final (tests, exitCode) = tester.getTestDirs(
            ['pubspec.yaml'],
            isFlutterOnly: false,
            isDartOnly: true,
          );

          expect(tests, isNull);
          expect(exitCode, isNotNull);
          expect(exitCode, isA<ExitCode>());
        });

        test('flutter only tests is enabled and is dart project', () {
          fs.file('pubspec.yaml').createSync();
          fs.file('pubspec.lock').createSync();

          final (tests, exitCode) = tester.getTestDirs(
            ['pubspec.yaml'],
            isFlutterOnly: true,
            isDartOnly: false,
          );

          expect(tests, isNull);
          expect(exitCode, isNotNull);
          expect(exitCode, isA<ExitCode>());
        });
      });
    });

    group('#writeOptimizedFiles', () {
      group('should write optimized files for dart', () {
        test('when test files exist', () {
          fs.file('test/some_test.dart').createSync(recursive: true);

          final testables = ['test'];
          final testableTools = {
            testables.first: _FakeDetermineFlutterOrDart.dart(),
          };

          final optimizedFiles = tester.prepareOptimizedFilesFromDirs(
            testables,
            testableTools,
          );

          expect(optimizedFiles, hasLength(1));
          expect(optimizedFiles.first.tool.isDart, isTrue);

          expect(
            fs
                .file('test/${TesterMixin.optimizedTestBasename}.dart')
                .existsSync(),
            isTrue,
          );
        });
      });

      group('should not write optimized files for flutter', () {
        test('when test files exist', () {
          fs.file('test/nest/automated_test.dart')
            ..createSync(recursive: true)
            ..writeAsStringSync('AutomatedTestWidgetsFlutterBinding');
          fs.file('test/nest/live_test.dart')
            ..createSync(recursive: true)
            ..writeAsStringSync('LiveTestWidgetsFlutterBinding');
          fs.file('test/nest/test_test.dart')
            ..createSync(recursive: true)
            ..writeAsStringSync('TestWidgetsFlutterBinding');
          fs.file('test/nest/unknown_test.dart')
            ..createSync(recursive: true)
            ..writeAsStringSync('');

          final testables = ['test'];
          final testableTools = {
            testables.first: _FakeDetermineFlutterOrDart.flutter(),
          };

          final optimizedFiles = tester.prepareOptimizedFilesFromDirs(
            testables,
            testableTools,
          );

          expect(optimizedFiles, hasLength(1));
          expect(optimizedFiles.first.tool.isFlutter, isTrue);

          final files = fs.directory('test').listSync().whereType<File>();

          expect(files, hasLength(0));
        });
      });

      group('optimized file content', () {
        final importPattern = RegExp(
          r"^import '(.*)' as _i\d+;$",
          multiLine: true,
        );

        test('should not include optimized file import', () {
          const optimizedFile =
              'test/${TesterMixin.optimizedTestBasename}.dart';

          fs.file('test/some_test.dart').createSync(recursive: true);
          fs.file(optimizedFile).createSync();

          final testables = ['test'];
          final testableTools = {
            testables.first: _FakeDetermineFlutterOrDart.dart(),
          };

          tester
              .prepareOptimizedFilesFromDirs(testables, testableTools)
              .toList();

          final optimizedFileContent = fs
              .file(optimizedFile)
              .readAsStringSync();

          final imports = importPattern.allMatches(optimizedFileContent);

          expect(imports.length, 1);
          expect(imports.first.group(1), 'some_test.dart');
        });

        test('should include files that end with _test.dart', () {
          fs.file('test/some_test.dart').createSync(recursive: true);

          final testables = ['test'];
          final testableTools = {
            testables.first: _FakeDetermineFlutterOrDart.dart(),
          };

          tester
              .prepareOptimizedFilesFromDirs(testables, testableTools)
              .toList();

          final optimizedFileContent = fs
              .file('test/${TesterMixin.optimizedTestBasename}.dart')
              .readAsStringSync();

          final imports = importPattern.allMatches(optimizedFileContent);

          expect(imports.length, 1);
          expect(imports.first.group(1), 'some_test.dart');
        });
      });

      group('should not write optimized files', () {
        test('when test files do not exist', () {
          fs.directory('test').createSync();
          final testables = ['test'];
          final testableTools = {
            testables.first: _FakeDetermineFlutterOrDart.dart(),
          };

          final optimizedFiles = tester.prepareOptimizedFilesFromDirs(
            testables,
            testableTools,
          );

          expect(optimizedFiles, hasLength(0));
        });
      });
    });

    group('#getCommandsToRun', () {
      test('should set cwd to project root when not optimizing', () {
        fs.file('test/some_test.dart').createSync(recursive: true);

        final testableTools = PackageToTest(
          tool: _FakeDetermineFlutterOrDart.dart(),
          packagePath: '.',
        );

        final commands = tester.getCommandsToRun(
          [testableTools],
          flutterArgs: [],
          dartArgs: [],
        );

        expect(commands.length, 1);
        expect((commands.first as ScriptToRun).workingDirectory, '.');
      });

      test('should set cwd to project root when optimizing', () {
        fs.file('test/.optimized_test.dart').createSync(recursive: true);

        final testableTools = PackageToTest(
          tool: _FakeDetermineFlutterOrDart.dart(),
          packagePath: '.',
          optimizedPath: 'test/.optimized_test.dart',
        );

        final commands = tester.getCommandsToRun(
          [testableTools],
          flutterArgs: [],
          dartArgs: [],
        );

        expect(commands.length, 1);
        expect((commands.first as ScriptToRun).workingDirectory, '.');
      });

      test('should return dart commands to run', () {
        fs.file('test/.optimized_test.dart').createSync(recursive: true);

        final testableTools = PackageToTest(
          tool: _FakeDetermineFlutterOrDart.dart(),
          packagePath: '',
          optimizedPath: 'test/.optimized_test.dart',
        );

        final commands = tester.getCommandsToRun(
          [testableTools],
          flutterArgs: [],
          dartArgs: [],
        );

        expect(commands.length, 1);
        expect(
          (commands.first as ScriptToRun).exe.trim(),
          'dart test test/.optimized_test.dart',
        );
      });

      test('should return flutter commands to run', () {
        fs.file('test/.optimized_test.dart').createSync(recursive: true);

        final testableTools = PackageToTest(
          tool: _FakeDetermineFlutterOrDart.flutter(),
          packagePath: '',
          optimizedPath: 'test/.optimized_test.dart',
        );

        final commands = tester.getCommandsToRun(
          [testableTools],
          flutterArgs: [],
          dartArgs: [],
        );

        expect(commands.length, 1);
        expect((commands.first as ScriptToRun).exe.trim(), 'flutter test');
      });

      test(
        'should add flutter args to flutter command and ignore dart args',
        () {
          fs.file('test/.optimized_test.dart').createSync(recursive: true);

          final testableTools = PackageToTest(
            tool: _FakeDetermineFlutterOrDart.flutter(),
            packagePath: '',
            optimizedPath: 'test/.optimized_test.dart',
          );

          final commands = tester.getCommandsToRun(
            [testableTools],
            flutterArgs: ['--flutter'],
            dartArgs: ['--dart'],
          );

          expect(commands.length, 1);
          expect(
            (commands.first as ScriptToRun).exe.trim(),
            'flutter test --flutter',
          );
        },
      );

      test('should add dart args to dart command and ignore flutter args', () {
        fs.file('test/.optimized_test.dart').createSync(recursive: true);

        final testableTools = PackageToTest(
          tool: _FakeDetermineFlutterOrDart.dart(),
          packagePath: '',
          optimizedPath: 'test/.optimized_test.dart',
        );

        final commands = tester.getCommandsToRun(
          [testableTools],
          flutterArgs: ['--flutter'],
          dartArgs: ['--dart'],
        );

        expect(commands.length, 1);
        expect(
          (commands.first as ScriptToRun).exe.trim(),
          'dart test test/.optimized_test.dart --dart',
        );
      });
    });

    group('#getTests', () {
      test('should return optimized tests when optimizing', () {
        fs.file('test/some_test.dart').createSync(recursive: true);

        final (tests, exitCode) = tester.getPackagesToTest(
          ['test'],
          {'test': _FakeDetermineFlutterOrDart.dart()},
          optimize: true,
        );

        expect(exitCode, isNull);
        expect(tests, isNotNull);
        tests!;

        expect(tests.length, 1);
        expect(
          tests.first.optimizedPath,
          'test/${TesterMixin.optimizedTestBasename}.dart',
        );
      });

      test('should return all tests when not optimizing', () {
        fs.file('test/some_test.dart').createSync(recursive: true);

        final (tests, exitCode) = tester.getPackagesToTest(
          ['test'],
          {'test': _FakeDetermineFlutterOrDart.dart()},
          optimize: false,
        );

        expect(exitCode, isNull);
        expect(tests, isNotNull);
        tests!;

        expect(tests.length, 1);
        expect(tests.first.packagePath, '');
      });

      test('should return exit code when no '
          'tests are found and not optimizing', () {
        final (tests, exitCode) = tester.getPackagesToTest(
          ['test'],
          {'test': _FakeDetermineFlutterOrDart.dart()},
          optimize: false,
        );

        expect(tests, isNull);
        expect(exitCode, isA<ExitCode>());
      });
    });

    group('#runCommands', () {
      test('should run commands', () async {
        when(
          () => bindings.runScript(any(), showOutput: any(named: 'showOutput')),
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
          () => bindings.runScript(any(), showOutput: any(named: 'showOutput')),
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
          () => bindings.runScript(any(), showOutput: any(named: 'showOutput')),
        ).called(1);
      });

      group('should run all commands', () {
        test('concurrently', () async {
          when(
            () =>
                bindings.runScript(any(), showOutput: any(named: 'showOutput')),
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
            () =>
                bindings.runScript(any(), showOutput: any(named: 'showOutput')),
          ).called(2);
        });

        test('not concurrently', () async {
          when(
            () =>
                bindings.runScript(any(), showOutput: any(named: 'showOutput')),
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
            () =>
                bindings.runScript(any(), showOutput: any(named: 'showOutput')),
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

class _FakeDetermineFlutterOrDart extends Fake
    implements DetermineFlutterOrDart {
  _FakeDetermineFlutterOrDart.flutter() : _isFlutter = true, _isDart = false;

  _FakeDetermineFlutterOrDart.dart() : _isFlutter = false, _isDart = true;

  final bool _isFlutter;
  final bool _isDart;

  @override
  bool get isDart => _isDart;
  @override
  bool get isFlutter => _isFlutter;

  @override
  String tool() {
    if (_isFlutter) {
      return 'flutter';
    } else if (_isDart) {
      return 'dart';
    } else {
      return 'unknown';
    }
  }
}
