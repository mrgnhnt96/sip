import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:file/src/interface/file_system.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/domain/domain.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:test/test.dart';

class _Tester extends TesterMixin {
  const _Tester({
    required this.bindings,
    required this.findFile,
    required this.fs,
    required this.logger,
    required this.pubspecLock,
    required this.pubspecYaml,
  });
  @override
  final Bindings bindings;

  @override
  final FindFile findFile;

  @override
  final FileSystem fs;

  @override
  final Logger logger;

  @override
  final PubspecLock pubspecLock;

  @override
  final PubspecYaml pubspecYaml;
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
  group('$TesterMixin', () {
    late _Tester tester;
    late FileSystem fs;
    late Bindings mockBindings;
    late Logger mockLogger;

    setUp(() {
      mockBindings = _MockBindings();
      mockLogger = _MockLogger();

      fs = MemoryFileSystem.test();

      tester = _Tester(
        bindings: mockBindings,
        pubspecYaml: PubspecYamlImpl(fs: fs),
        pubspecLock: PubspecLockImpl(fs: fs),
        findFile: FindFile(fs: fs),
        fs: fs,
        logger: mockLogger,
      );
    });

    group('#packageRootFor', () {
      group('successfully returns the path when', () {
        test('a dir path is provided', () {
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

    group('#pubspecs', () {
      group('when not recursive', () {
        test('should return the root pubspec.yaml', () async {
          fs.file('pubspec.yaml').createSync();

          final pubspecs = await tester.pubspecs(isRecursive: false);

          expect(pubspecs, isNotNull);
          expect(pubspecs.length, 1);
        });

        test('should return not return sub pubspec.yamls', () async {
          fs.file('pubspec.yaml').createSync();
          fs.file('sub/pubspec.yaml').createSync(recursive: true);

          final pubspecs = await tester.pubspecs(isRecursive: false);

          expect(pubspecs, isNotNull);
          expect(pubspecs.length, 1);
        });
      });

      group('when recursive', () {
        test('should return the root pubspec.yaml', () async {
          fs.file('pubspec.yaml').createSync();

          final pubspecs = await tester.pubspecs(isRecursive: true);

          expect(pubspecs, isNotNull);
          expect(pubspecs.length, 1);
        });

        test('should return all pubspec.yamls and root', () async {
          fs.file('pubspec.yaml').createSync();
          fs.file('sub/pubspec.yaml').createSync(recursive: true);

          final pubspecs = await tester.pubspecs(isRecursive: true);

          expect(pubspecs, isNotNull);
          expect(pubspecs.length, 2);
        });

        test('should return all pubspec.yamls even when root does not exist',
            () async {
          fs.file('sub/pubspec.yaml').createSync(recursive: true);

          final pubspecs = await tester.pubspecs(isRecursive: true);

          expect(pubspecs.length, 1);
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

          final optimizedFiles =
              tester.writeOptimizedFiles(testables, testableTools);

          expect(optimizedFiles.length, 1);
          expect(optimizedFiles.entries.first.value.isDart, isTrue);

          expect(
            fs
                .file('test/${TesterMixin.optimizedTestFileName('dart')}')
                .existsSync(),
            isTrue,
          );
        });
      });

      group('should write optimized files for flutter', () {
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

          final optimizedFiles =
              tester.writeOptimizedFiles(testables, testableTools);

          expect(optimizedFiles.length, 4);
          expect(optimizedFiles.entries.first.value.isFlutter, isTrue);

          final files = fs.directory('test').listSync().whereType<File>();

          expect(files.length, 4);
          final tests = {
            TesterMixin.optimizedTestFileName('automated'),
            TesterMixin.optimizedTestFileName('test'),
            TesterMixin.optimizedTestFileName('live'),
            TesterMixin.optimizedTestFileName('flutter'),
          };

          for (final file in files) {
            expect(tests.contains(file.basename), isTrue);
          }
        });
      });

      group('optimized file content', () {
        final importPattern =
            RegExp(r"^import '(.*)' as _i\d+;$", multiLine: true);

        test('should not include optimized file import', () {
          final optimizedFile =
              'test/${TesterMixin.optimizedTestFileName('dart')}';

          fs.file('test/some_test.dart').createSync(recursive: true);
          fs.file(optimizedFile).createSync();

          final testables = ['test'];
          final testableTools = {
            testables.first: _FakeDetermineFlutterOrDart.dart(),
          };

          tester.writeOptimizedFiles(testables, testableTools);

          final optimizedFileContent =
              fs.file(optimizedFile).readAsStringSync();

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

          tester.writeOptimizedFiles(testables, testableTools);

          final optimizedFileContent = fs
              .file('test/${TesterMixin.optimizedTestFileName('dart')}')
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
              tester.writeOptimizedFiles(testables, testableTools);

          expect(optimizedFiles.length, 0);
        });
      });
    });

    group('#getCommandsToRun', () {
      test('should set cwd to project root when not optimizing', () {
        fs.file('test/some_test.dart').createSync(recursive: true);

        final testableTools = {
          'test': _FakeDetermineFlutterOrDart.dart(),
        };

        final commands = tester.getCommandsToRun(
          testableTools,
          flutterArgs: [],
          dartArgs: [],
        );

        expect(commands.length, 1);
        expect(commands.first.workingDirectory, '.');
      });

      test('should set cwd to project root when optimizing', () {
        fs.file('test/.optimized_test.dart').createSync(recursive: true);

        final testableTools = {
          'test/.optimized_test.dart': _FakeDetermineFlutterOrDart.dart(),
        };

        final commands = tester.getCommandsToRun(
          testableTools,
          flutterArgs: [],
          dartArgs: [],
        );

        expect(commands.length, 1);
        expect(commands.first.workingDirectory, '.');
      });

      test('should return dart commands to run', () {
        fs.file('test/.optimized_test.dart').createSync(recursive: true);

        final testableTools = {
          'test/.optimized_test.dart': _FakeDetermineFlutterOrDart.dart(),
        };

        final commands = tester.getCommandsToRun(
          testableTools,
          flutterArgs: [],
          dartArgs: [],
        );

        expect(commands.length, 1);
        expect(
          commands.first.command.trim(),
          'dart test test/.optimized_test.dart',
        );
      });

      test('should return flutter commands to run', () {
        fs.file('test/.optimized_test.dart').createSync(recursive: true);

        final testableTools = {
          'test/.optimized_test.dart': _FakeDetermineFlutterOrDart.flutter(),
        };

        final commands = tester.getCommandsToRun(
          testableTools,
          flutterArgs: [],
          dartArgs: [],
        );

        expect(commands.length, 1);
        expect(
          commands.first.command.trim(),
          'flutter test test/.optimized_test.dart',
        );
      });

      test(
        'should add flutter args to flutter command and ignore dart args',
        () {
          fs.file('test/.optimized_test.dart').createSync(recursive: true);

          final testableTools = {
            'test/.optimized_test.dart': _FakeDetermineFlutterOrDart.flutter(),
          };

          final commands = tester.getCommandsToRun(
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
          fs.file('test/.optimized_test.dart').createSync(recursive: true);

          final testableTools = {
            'test/.optimized_test.dart': _FakeDetermineFlutterOrDart.dart(),
          };

          final commands = tester.getCommandsToRun(
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

    group('#getTests', () {
      test('should return optimized tests when optimizing', () {
        fs.file('test/some_test.dart').createSync(recursive: true);

        final (tests, exitCode) = tester.getTests(
          ['test'],
          {'test': _FakeDetermineFlutterOrDart.dart()},
          optimize: true,
        );

        expect(exitCode, isNull);
        expect(tests, isNotNull);
        tests!;

        expect(tests.length, 1);
        expect(
          tests.keys.first,
          'test/${TesterMixin.optimizedTestFileName('dart')}',
        );
      });

      test('should return all tests when not optimizing', () {
        fs.file('test/some_test.dart').createSync(recursive: true);

        final (tests, exitCode) = tester.getTests(
          ['test'],
          {'test': _FakeDetermineFlutterOrDart.dart()},
          optimize: false,
        );

        expect(exitCode, isNull);
        expect(tests, isNotNull);
        tests!;

        expect(tests.length, 1);
        expect(tests.keys.first, 'test');
      });

      test(
          'should return exit code when no '
          'tests are found and not optimizing', () {
        final (tests, exitCode) = tester.getTests(
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

        final results = await tester.runCommands(
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

        final results = await tester.runCommands(
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

          final results = await tester.runCommands(
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

          final results = await tester.runCommands(
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
        const path = 'test/${TesterMixin.optimizedTestBasename}';
        fs.file(path).createSync(recursive: true);

        tester.cleanUp([path]);

        expect(fs.file(path).existsSync(), isFalse);
      });

      test('should not delete non optimized file', () {
        fs.file('test/other.dart').createSync(recursive: true);

        tester.cleanUp(['test/other.dart']);

        expect(fs.file('test/other.dart').existsSync(), isTrue);
      });
    });
  });
}
