import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/src/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/find_file.dart';
import 'package:sip_cli/src/domain/pubspec_lock.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/utils/package.dart';
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
    late FindFile findFile;
    late PubspecLock pubspecLock;
    late ScriptsYaml scriptsYaml;

    setUp(() {
      bindings = _MockBindings();
      logger = _MockLogger();
      findFile = _MockFindFile();
      pubspecLock = _MockPubspecLock();
      scriptsYaml = _MockScriptsYaml();

      fs = MemoryFileSystem.test();

      tester = const _Tester();

      // Set up default mocks for Package dependencies
      when(() => findFile.retrieveContent(any())).thenReturn(null);
      when(() => pubspecLock.findIn(any())).thenReturn(null);
      when(() => scriptsYaml.executables()).thenReturn(null);
    });

    @isTest
    void test(
      String description,
      FutureOr<void> Function() fn, {
      Object? skip,
    }) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        bindings: () => bindings,
        logger: () => logger,
        findFile: () => findFile,
        pubspecLock: () => pubspecLock,
        scriptsYaml: () => scriptsYaml,
        skip: skip,
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

      test(
        'should bail when first fails',
        skip: 'Tests do not fail due to exit code, it fails with test output',
        () async {
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
        },
      );

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

    group('#createTestCommand', () {
      test('should show root directory when no tests provided and at root', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');

        final pkg = Package('/project/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: [],
          bail: false,
        );

        // Extract path from label (format: "Running (dart) tests in <path>")
        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        expect(label, contains('tests in .'));
      });

      test('should show provided test file path', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs.file('/project/test/some_test.dart').createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/project/test/some_test.dart'],
          bail: false,
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        expect(label, contains('tests in test'));
      });

      test('should show provided test directory path', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs.directory('/project/test/subdir').createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/project/test/subdir'],
          bail: false,
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        expect(label, contains('tests in test/subdir'));
      });

      test('should show relative path when in subdirectory', () {
        // Set up nested package
        fs.currentDirectory = fs.directory('/workspace')
          ..createSync(recursive: true);
        fs.directory('/workspace/packages/my_pkg').createSync(recursive: true);
        fs.file('/workspace/packages/my_pkg/pubspec.yaml').createSync();
        fs
            .file('/workspace/packages/my_pkg/pubspec.yaml')
            .writeAsStringSync('name: my_pkg');
        fs
            .file('/workspace/packages/my_pkg/test/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/workspace/packages/my_pkg/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/workspace/packages/my_pkg/test/some_test.dart'],
          bail: false,
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        expect(label, contains('tests in packages/my_pkg/test'));
      });

      test('should show root when no tests provided in nested package', () {
        // Set up nested package
        fs.currentDirectory = fs.directory('/workspace')
          ..createSync(recursive: true);
        fs.directory('/workspace/packages/my_pkg').createSync(recursive: true);
        fs.file('/workspace/packages/my_pkg/pubspec.yaml').createSync();
        fs
            .file('/workspace/packages/my_pkg/pubspec.yaml')
            .writeAsStringSync('name: my_pkg');

        final pkg = Package('/workspace/packages/my_pkg/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: [],
          bail: false,
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        // Should show the package's relative path from current directory
        expect(label, contains('tests in packages/my_pkg'));
      });

      test('should handle relative test paths', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs
            .file('/project/test/subdir/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        // Pass relative path (relative to package path)
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['test/subdir/some_test.dart'],
          bail: false,
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        expect(label, contains('tests in test/subdir'));
      });

      test('should show provided directory, not subdirectories '
          'where test files were found', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        // Create test file in a subdirectory
        fs
            .file('/project/test/lib/screens/home_profile/edit/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        // When a directory is provided, show that directory,
        // not the subdirectory
        // where test files were found
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: [
            '/project/test/lib/screens/home_profile/edit',
          ], // resolved test dir
          bail: false,
          providedPaths: [
            'test/lib/screens/home_profile',
          ], // original provided path
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        // Should show the provided directory, not the subdirectory
        expect(label, contains('tests in test/lib/screens/home_profile'));
        expect(label, isNot(contains('edit')));
      });

      test('should show "." when "." is provided', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs
            .file('/project/test/utils/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        // When "." is provided, show "." not the resolved test directories
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/project/test/utils'], // resolved test dir
          bail: false,
          providedPaths: ['.'], // original provided path
        );

        final scriptToRun = command as ScriptToRun;
        final label = scriptToRun.label;
        // Should show "." not "test/utils"
        expect(label, contains('tests in .'));
        expect(label, isNot(contains('test/utils')));
      });

      test(
        'should show "." when no paths are provided (sip test with no args)',
        () {
          // Set up root directory with pubspec.yaml
          fs.currentDirectory = fs.directory('/project')
            ..createSync(recursive: true);
          fs.file('/project/pubspec.yaml').createSync();
          fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
          fs
              .file('/project/test/utils/some_test.dart')
              .createSync(recursive: true);

          final pkg = Package('/project/pubspec.yaml');
          // When no paths are provided, show "." not the
          // resolved test directories
          final command = tester.createTestCommand(
            pkg: pkg,
            tests: ['/project/test/utils'], // resolved test dir from package
            bail: false,
            providedPaths: [], // empty list means no paths were provided
          );

          final scriptToRun = command as ScriptToRun;
          final label = scriptToRun.label;
          // Should show "." not "test/utils"
          expect(label, contains('tests in .'));
          expect(label, isNot(contains('test/utils')));
        },
      );

      test('should not include test paths in command when "." is provided', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs
            .file('/project/test/utils/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/project/test/utils'], // resolved test dir
          bail: false,
          providedPaths: ['.'], // original provided path
        );

        final scriptToRun = command as ScriptToRun;
        final script = scriptToRun.exe;
        // Should not include test paths, just run "dart test" or "flutter test"
        expect(script, isNot(contains('test/utils')));
        expect(script, contains('test'));
      });

      test(
        'should not include test paths in command when "test" is provided',
        () {
          // Set up root directory with pubspec.yaml
          fs.currentDirectory = fs.directory('/project')
            ..createSync(recursive: true);
          fs.file('/project/pubspec.yaml').createSync();
          fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
          fs
              .file('/project/test/utils/some_test.dart')
              .createSync(recursive: true);

          final pkg = Package('/project/pubspec.yaml');
          final command = tester.createTestCommand(
            pkg: pkg,
            tests: ['/project/test/utils'], // resolved test dir
            bail: false,
            providedPaths: ['test'], // original provided path
          );

          final scriptToRun = command as ScriptToRun;
          final script = scriptToRun.exe;
          // Should not include test paths, just run "dart test"
          // or "flutter test"
          expect(script, isNot(contains('test/utils')));
          expect(script, contains('test'));
        },
      );

      test('should not include test paths in command when '
          'no paths provided', () {
        // Set up root directory with pubspec.yaml
        fs.currentDirectory = fs.directory('/project')
          ..createSync(recursive: true);
        fs.file('/project/pubspec.yaml').createSync();
        fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
        fs
            .file('/project/test/utils/some_test.dart')
            .createSync(recursive: true);

        final pkg = Package('/project/pubspec.yaml');
        final command = tester.createTestCommand(
          pkg: pkg,
          tests: ['/project/test/utils'], // resolved test dir
          bail: false,
          providedPaths: [], // no paths provided
        );

        final scriptToRun = command as ScriptToRun;
        final script = scriptToRun.exe;
        // Should not include test paths, just run "dart test" or "flutter test"
        expect(script, isNot(contains('test/utils')));
        expect(script, contains('test'));
      });

      test(
        'should include test paths in command when specific path is provided',
        () {
          // Set up root directory with pubspec.yaml
          fs.currentDirectory = fs.directory('/project')
            ..createSync(recursive: true);
          fs.file('/project/pubspec.yaml').createSync();
          fs.file('/project/pubspec.yaml').writeAsStringSync('name: project');
          fs
              .file('/project/test/utils/some_test.dart')
              .createSync(recursive: true);

          final pkg = Package('/project/pubspec.yaml');
          final command = tester.createTestCommand(
            pkg: pkg,
            tests: ['/project/test/utils'], // resolved test dir
            bail: false,
            providedPaths: ['test/utils'], // specific path provided
          );

          final scriptToRun = command as ScriptToRun;
          final script = scriptToRun.exe;
          // Should include the test path
          expect(script, contains('test/utils'));
        },
      );
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

class _MockFindFile extends Mock implements FindFile {}

class _MockPubspecLock extends Mock implements PubspecLock {}

class _MockScriptsYaml extends Mock implements ScriptsYaml {}
