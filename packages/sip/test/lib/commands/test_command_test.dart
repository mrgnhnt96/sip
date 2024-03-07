import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/commands/test_command/test_command.dart';
import 'package:sip_cli/domain/domain.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:test/test.dart';

class _MockBindings extends Mock implements Bindings {}

class _MockLogger extends Mock implements Logger {
  @override
  Progress progress(String message, {ProgressOptions? options}) {
    return _MockProgress();
  }
}

class _MockProgress extends Mock implements Progress {}

class _FakeDetermineFlutterOrDart extends Fake
    implements DetermineFlutterOrDart {
  _FakeDetermineFlutterOrDart.flutter()
      : _isFlutter = true,
        _isDart = false;

  _FakeDetermineFlutterOrDart.dart()
      : _isFlutter = false,
        _isDart = true;

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

void main() {
  group('$TestCommand', () {
    late TestCommand testCommand;
    late FileSystem fs;
    late Bindings mockBindings;
    late Logger mockLogger;

    setUp(() {
      mockBindings = _MockBindings();
      mockLogger = _MockLogger();

      fs = MemoryFileSystem.test();

      testCommand = TestCommand(
        bindings: mockBindings,
        pubspecYaml: PubspecYamlImpl(fs: fs),
        pubspecLock: PubspecLockImpl(fs: fs),
        findFile: FindFile(fs: fs),
        fs: fs,
        logger: mockLogger,
      );
    });

    group('#pubspecs', () {
      group('when not recursive', () {
        test('should return the root pubspec.yaml', () async {
          fs.file('pubspec.yaml').createSync();

          final pubspecs = await testCommand.pubspecs(isRecursive: false);

          expect(pubspecs, isNotNull);
          expect(pubspecs.length, 1);
        });

        test('should return not return sub pubspec.yamls', () async {
          fs.file('pubspec.yaml').createSync();
          fs.file('sub/pubspec.yaml').createSync(recursive: true);

          final pubspecs = await testCommand.pubspecs(isRecursive: false);

          expect(pubspecs, isNotNull);
          expect(pubspecs.length, 1);
        });
      });

      group('when recursive', () {
        test('should return the root pubspec.yaml', () async {
          fs.file('pubspec.yaml').createSync();

          final pubspecs = await testCommand.pubspecs(isRecursive: true);

          expect(pubspecs, isNotNull);
          expect(pubspecs.length, 1);
        });

        test('should return all pubspec.yamls and root', () async {
          fs.file('pubspec.yaml').createSync();
          fs.file('sub/pubspec.yaml').createSync(recursive: true);

          final pubspecs = await testCommand.pubspecs(isRecursive: true);

          expect(pubspecs, isNotNull);
          expect(pubspecs.length, 2);
        });

        test('should return all pubspec.yamls even when root does not exist',
            () async {
          fs.file('sub/pubspec.yaml').createSync(recursive: true);

          final pubspecs = await testCommand.pubspecs(isRecursive: true);

          expect(pubspecs.length, 1);
        });
      });
    });

    group('#testables', () {
      group('should return testable path when', () {
        test('test dir exists', () async {
          fs.file('pubspec.yaml').createSync();
          fs.directory('test').createSync();

          final (testables, testableTool) = testCommand.getTestables(
            ['pubspec.yaml'],
            isFlutterOnly: false,
            isDartOnly: false,
          );

          expect(testables.length, 1);
          expect(testableTool.length, 1);
          expect(testables.length, testableTool.length);
        });

        test('dart only tests is enabled and is dart project', () {
          fs.file('pubspec.yaml').createSync();
          fs.file('pubspec.lock').createSync();
          fs.directory('test').createSync();

          final (testables, testableTool) = testCommand.getTestables(
            ['pubspec.yaml'],
            isFlutterOnly: false,
            isDartOnly: true,
          );

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

          final (testables, testableTool) = testCommand.getTestables(
            ['pubspec.yaml'],
            isFlutterOnly: true,
            isDartOnly: false,
          );

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

          final (testables, testableTool) = testCommand.getTestables(
            ['pubspec.yaml'],
            isFlutterOnly: false,
            isDartOnly: false,
          );

          expect(testables.length, isZero);
          expect(testableTool.length, isZero);
          expect(testables.length, testableTool.length);
        });

        test('dart only tests is enabled and is flutter project', () {
          fs.file('pubspec.yaml').createSync();
          fs.file('pubspec.lock')
            ..createSync()
            ..writeAsString('flutter');

          final (testables, testableTool) = testCommand.getTestables(
            ['pubspec.yaml'],
            isFlutterOnly: false,
            isDartOnly: true,
          );

          expect(testables.length, isZero);
          expect(testableTool.length, isZero);
          expect(testables.length, testableTool.length);
        });

        test('flutter only tests is enabled and is dart project', () {
          fs.file('pubspec.yaml').createSync();
          fs.file('pubspec.lock').createSync();

          final (testables, testableTool) = testCommand.getTestables(
            ['pubspec.yaml'],
            isFlutterOnly: true,
            isDartOnly: false,
          );

          expect(testables.length, isZero);
          expect(testableTool.length, isZero);
          expect(testables.length, testableTool.length);
        });
      });
    });

    group('#writeOptimizedFiles', () {
      group('should write optimized files', () {
        test('when test files exist', () {
          fs.file('test/some_test.dart').createSync(recursive: true);

          final testables = ['test'];
          final testableTools = {
            testables.first: _FakeDetermineFlutterOrDart.dart(),
          };

          final optimizedFiles =
              testCommand.writeOptimizedFiles(testables, testableTools);

          expect(optimizedFiles.length, 1);
          expect(optimizedFiles.entries.first.value.isDart, isTrue);

          expect(
            fs.file('test/${TestCommand.optimizedTestFileName}').existsSync(),
            isTrue,
          );
        });
      });

      group('optimized file content', () {
        final importPattern =
            RegExp(r"^import '(.*)' as _i\d+;$", multiLine: true);

        test('should not include optimized file import', () {
          fs.file('test/some_test.dart').createSync(recursive: true);
          fs.file('test/${TestCommand.optimizedTestFileName}').createSync();

          final testables = ['test'];
          final testableTools = {
            testables.first: _FakeDetermineFlutterOrDart.dart(),
          };

          testCommand.writeOptimizedFiles(testables, testableTools);

          final optimizedFileContent = fs
              .file('test/${TestCommand.optimizedTestFileName}')
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

          testCommand.writeOptimizedFiles(testables, testableTools);

          final optimizedFileContent = fs
              .file('test/${TestCommand.optimizedTestFileName}')
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

          final optimizedFiles =
              testCommand.writeOptimizedFiles(testables, testableTools);

          expect(optimizedFiles.length, 0);
        });
      });
    });

    group('#getCommandsToRun', () {
      test('should return dart commands to run', () {
        final testableTools = {
          'test/.optimized_test.dart': _FakeDetermineFlutterOrDart.dart(),
        };

        final commands = testCommand
            .getCommandsToRun(testableTools, flutterArgs: [], dartArgs: []);

        expect(commands.length, 1);
        expect(
          commands.first.command.trim(),
          'dart test test/.optimized_test.dart',
        );
      });

      test('should return flutter commands to run', () {
        final testableTools = {
          'test/.optimized_test.dart': _FakeDetermineFlutterOrDart.flutter(),
        };

        final commands = testCommand
            .getCommandsToRun(testableTools, flutterArgs: [], dartArgs: []);

        expect(commands.length, 1);
        expect(
          commands.first.command.trim(),
          'flutter test test/.optimized_test.dart',
        );
      });

      test(
        'should add flutter args to flutter command and ignore dart args',
        () {
          final testableTools = {
            'test/.optimized_test.dart': _FakeDetermineFlutterOrDart.flutter(),
          };

          final commands = testCommand.getCommandsToRun(
            testableTools,
            flutterArgs: ['--flutter'],
            dartArgs: ['--dart'],
          );

          expect(commands.length, 1);
          expect(
            commands.first.command.trim(),
            'flutter test test/.optimized_test.dart --flutter',
          );
        },
      );

      test(
        'should add dart args to dart command and ignore flutter args',
        () {
          final testableTools = {
            'test/.optimized_test.dart': _FakeDetermineFlutterOrDart.dart(),
          };

          final commands = testCommand.getCommandsToRun(
            testableTools,
            flutterArgs: ['--flutter'],
            dartArgs: ['--dart'],
          );

          expect(commands.length, 1);
          expect(
            commands.first.command.trim(),
            'dart test test/.optimized_test.dart --dart',
          );
        },
      );
    });

    group('#runCommands', () {
      test('should run commands', () async {
        when(
          () => mockBindings.runScript(
            any(),
            showOutput: any(named: 'showOutput'),
          ),
        ).thenAnswer((_) => Future.value(0));

        final commands = [
          const CommandToRun(
            command: 'something',
            workingDirectory: '.',
            keys: [],
          ),
        ];

        final results = await testCommand.runCommands(
          commands,
          bail: false,
          runConcurrently: false,
        );

        expect(results, ExitCode.success);
      });

      test('should bail when first fails', () async {
        when(
          () => mockBindings.runScript(
            any(),
            showOutput: any(named: 'showOutput'),
          ),
        ).thenAnswer((_) => Future.value(1));

        final commands = [
          const CommandToRun(
            command: 'something',
            workingDirectory: '.',
            keys: [],
          ),
          const CommandToRun(
            command: 'else',
            workingDirectory: '.',
            keys: [],
          ),
        ];

        final results = await testCommand.runCommands(
          commands,
          bail: true,
          runConcurrently: false,
        );

        expect(results.code, 1);
        verify(
          () => mockBindings.runScript(
            any(),
            showOutput: any(named: 'showOutput'),
          ),
        ).called(1);
      });

      group('should run all commands', () {
        test('concurrently', () async {
          when(
            () => mockBindings.runScript(
              any(),
              showOutput: any(named: 'showOutput'),
            ),
          ).thenAnswer((_) => Future.value(0));

          final commands = [
            const CommandToRun(
              command: 'something',
              workingDirectory: '.',
              keys: [],
            ),
            const CommandToRun(
              command: 'else',
              workingDirectory: '.',
              keys: [],
            ),
          ];

          final results = await testCommand.runCommands(
            commands,
            bail: false,
            runConcurrently: true,
          );

          expect(results, ExitCode.success);
          verify(
            () => mockBindings.runScript(
              any(),
              showOutput: any(named: 'showOutput'),
            ),
          ).called(2);
        });

        test('not concurrently', () async {
          when(
            () => mockBindings.runScript(
              any(),
              showOutput: any(named: 'showOutput'),
            ),
          ).thenAnswer((_) => Future.value(0));

          final commands = [
            const CommandToRun(
              command: 'something',
              workingDirectory: '.',
              keys: [],
            ),
            const CommandToRun(
              command: 'else',
              workingDirectory: '.',
              keys: [],
            ),
          ];

          final results = await testCommand.runCommands(
            commands,
            bail: false,
            runConcurrently: true,
          );

          expect(results, ExitCode.success);
          verify(
            () => mockBindings.runScript(
              any(),
              showOutput: any(named: 'showOutput'),
            ),
          ).called(2);
        });
      });
    });

    group('#cleanUp', () {
      test('should delete optimized files', () {
        fs.file('test/.optimized_file.dart').createSync(recursive: true);

        testCommand.cleanUp(['test/.optimized_file.dart']);

        expect(fs.file('test/.optimized_file.dart').existsSync(), isFalse);
      });
    });
  });
}
