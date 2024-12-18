import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/commands/test_watch_command.dart';
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/package_to_test.dart';
import 'package:sip_cli/domain/pubspec_lock_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/domain/scripts_yaml_impl.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/key_press_listener.dart';
import 'package:test/test.dart';

void main() {
  group(TestWatchCommand, () {
    late TestWatchCommand testWatchCommand;
    late FileSystem fs;
    late _MockLogger mockLogger;

    setUp(() {
      fs = MemoryFileSystem.test();

      mockLogger = _MockLogger();

      testWatchCommand = TestWatchCommand(
        bindings: _MockBindings(),
        findFile: FindFile(fs: fs),
        fs: fs,
        logger: mockLogger,
        pubspecLock: PubspecLockImpl(fs: fs),
        pubspecYaml: PubspecYamlImpl(fs: fs),
        keyPressListener: KeyPressListener(logger: mockLogger),
        scriptsYaml: ScriptsYamlImpl(fs: fs),
      );
    });

    group('#findTest', () {
      group('return directory successfully', () {
        group('when root level', () {
          test(
            'and modified is in lib',
            () async {
              final testDirs = PackageToTest(
                tool: _FakeDetermineFlutterOrDart(),
                packagePath: '',
              );

              const modifiedFile = 'lib/foo.dart';

              final result = await testWatchCommand.findTest(
                [testDirs],
                modifiedFile,
                returnTestFile: false,
              );

              expect(result, isNotNull);
              expect(result?.packagePath, '');
            },
          );

          test(
            'and modified is in test',
            () async {
              final testDirs = PackageToTest(
                tool: _FakeDetermineFlutterOrDart(),
                packagePath: '',
              );

              const modifiedFile = 'test/foo_test.dart';

              final result = await testWatchCommand.findTest(
                [testDirs],
                modifiedFile,
                returnTestFile: false,
              );

              expect(result, isNotNull);
              expect(result?.packagePath, '');
            },
          );
        });

        group('when nested level', () {
          test(
            'and modified is in lib',
            () async {
              final testDirs = {
                PackageToTest(
                  tool: _FakeDetermineFlutterOrDart(),
                  packagePath: '',
                ),
                PackageToTest(
                  tool: _FakeDetermineFlutterOrDart(),
                  packagePath: 'packages/foo',
                ),
              };

              const modifiedFile = 'packages/foo/lib/foo.dart';

              final result = await testWatchCommand.findTest(
                testDirs,
                modifiedFile,
                returnTestFile: false,
              );

              expect(result, isNotNull);
              expect(result?.packagePath, 'packages/foo');
            },
          );

          test(
            'and modified is in test',
            () async {
              final testDirs = [
                PackageToTest(
                  tool: _FakeDetermineFlutterOrDart(),
                  packagePath: '',
                ),
                PackageToTest(
                  tool: _FakeDetermineFlutterOrDart(),
                  packagePath: 'packages/foo',
                ),
              ];

              const modifiedFile = 'packages/foo/test/foo_test.dart';

              final result = await testWatchCommand.findTest(
                testDirs,
                modifiedFile,
                returnTestFile: false,
              );

              expect(result, isNotNull);
              expect(result?.packagePath, 'packages/foo');
            },
          );

          test('when there are similar starting paths', () async {
            final testDirs = {
              PackageToTest(
                tool: _FakeDetermineFlutterOrDart(),
                packagePath: '',
              ),
              PackageToTest(
                tool: _FakeDetermineFlutterOrDart(),
                packagePath: 'packages/foo',
              ),
              PackageToTest(
                tool: _FakeDetermineFlutterOrDart(),
                packagePath: 'packages/foo/bar',
              ),
            };

            const modifiedFile = 'packages/foo/bar/test/foo_test.dart';

            final result = await testWatchCommand.findTest(
              testDirs,
              modifiedFile,
              returnTestFile: false,
            );

            expect(result, isNotNull);
            expect(result?.packagePath, 'packages/foo/bar');
          });
        });
      });

      group('returns file successfully', () {
        group('when root level', () {
          test('and modified is in lib', () async {
            fs.file('test/foo_test.dart').createSync(recursive: true);

            final testDirs = PackageToTest(
              tool: _FakeDetermineFlutterOrDart(),
              packagePath: '',
            );

            const modifiedFile = 'lib/foo.dart';

            final result = await testWatchCommand.findTest(
              [testDirs],
              modifiedFile,
              returnTestFile: true,
            );

            expect(result, isNotNull);
            expect(result?.optimizedPath, 'test/foo_test.dart');
          });

          test('and modified is in test', () async {
            fs.file('test/foo_test.dart').createSync(recursive: true);

            final testDirs = PackageToTest(
              tool: _FakeDetermineFlutterOrDart(),
              packagePath: '',
            );

            const modifiedFile = 'test/foo_test.dart';

            final result = await testWatchCommand.findTest(
              [testDirs],
              modifiedFile,
              returnTestFile: true,
            );

            expect(result, isNotNull);
            expect(result?.optimizedPath, 'test/foo_test.dart');
          });
        });

        test('finds the right file when many files are found', () async {
          fs.file('my_project/test/foo_test.dart').createSync(recursive: true);
          fs
              .file('my_project/test/utils/foo_test.dart')
              .createSync(recursive: true);
          fs
              .file('my_project/test/something/else/foo_test.dart')
              .createSync(recursive: true);

          final testDirs = PackageToTest(
            tool: _FakeDetermineFlutterOrDart(),
            packagePath: 'my_project',
          );

          const expected = {
            'my_project/lib/foo.dart': 'my_project/test/foo_test.dart',
            'my_project/lib/utils/foo.dart':
                'my_project/test/utils/foo_test.dart',
            'my_project/lib/something/else/foo.dart':
                'my_project/test/something/else/foo_test.dart',
          };

          for (final entry in expected.entries) {
            final result = await testWatchCommand.findTest(
              [testDirs],
              entry.key,
              returnTestFile: true,
            );

            expect(result, isNotNull);
            expect(result?.optimizedPath, entry.value);
          }
        });

        test('does not return test file when nothing found', () async {
          final testDirs = PackageToTest(
            tool: _FakeDetermineFlutterOrDart(),
            packagePath: '',
          );

          const modifiedFile = 'lib/foo.dart';

          final result = await testWatchCommand.findTest(
            [testDirs],
            modifiedFile,
            returnTestFile: true,
          );

          expect(result, isNull);
        });

        test('does not return test dir when nothing found', () async {
          final testDirs = PackageToTest(
            tool: _FakeDetermineFlutterOrDart(),
            packagePath: '',
          );

          const modifiedFile = 'packages/ui/lib/foo.dart';

          final result = await testWatchCommand.findTest(
            [testDirs],
            modifiedFile,
            returnTestFile: false,
          );

          expect(result, isNull);
        });
      });
    });
  });
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
  @override
  bool get isDart => true;
  @override
  bool get isFlutter => false;

  @override
  String tool() {
    return 'dart';
  }
}
