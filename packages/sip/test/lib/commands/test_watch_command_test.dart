import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/commands/test_watch_command.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/key_press_listener.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:test/test.dart';

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
  group('$TestWatchCommand', () {
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
      );
    });

    group('#findTest', () {
      group('return directory successfully', () {
        group('when root level', () {
          test(
            'and modified is in lib',
            () async {
              final testDirs = {
                'test': _FakeDetermineFlutterOrDart.dart(),
              };

              const modifiedFile = 'lib/foo.dart';

              final result = await testWatchCommand.findTest(
                testDirs,
                modifiedFile,
                returnTestFile: false,
              );

              expect(result, isNotNull);

              final (dir, tool) = result!;

              expect(dir, 'test');
              expect(tool.isDart, isTrue);
            },
          );

          test(
            'and modified is in test',
            () async {
              final testDirs = {
                'test': _FakeDetermineFlutterOrDart.dart(),
              };

              const modifiedFile = 'test/foo_test.dart';

              final result = await testWatchCommand.findTest(
                testDirs,
                modifiedFile,
                returnTestFile: false,
              );

              expect(result, isNotNull);

              final (dir, tool) = result!;

              expect(dir, 'test');
              expect(tool.isDart, isTrue);
            },
          );
        });

        group('when nested level', () {
          test(
            'and modified is in lib',
            () async {
              final testDirs = {
                'test': _FakeDetermineFlutterOrDart.dart(),
                'packages/foo/test': _FakeDetermineFlutterOrDart.dart(),
              };

              const modifiedFile = 'packages/foo/lib/foo.dart';

              final result = await testWatchCommand.findTest(
                testDirs,
                modifiedFile,
                returnTestFile: false,
              );

              expect(result, isNotNull);

              final (dir, tool) = result!;

              expect(dir, 'packages/foo/test');
              expect(tool.isDart, isTrue);
            },
          );

          test(
            'and modified is in test',
            () async {
              final testDirs = {
                'test': _FakeDetermineFlutterOrDart.dart(),
                'packages/foo/test': _FakeDetermineFlutterOrDart.dart(),
              };

              const modifiedFile = 'packages/foo/test/foo_test.dart';

              final result = await testWatchCommand.findTest(
                testDirs,
                modifiedFile,
                returnTestFile: false,
              );

              expect(result, isNotNull);

              final (dir, tool) = result!;

              expect(dir, 'packages/foo/test');
              expect(tool.isDart, isTrue);
            },
          );

          test('when there are similar starting paths', () async {
            final testDirs = {
              'test': _FakeDetermineFlutterOrDart.dart(),
              'packages/foo/test': _FakeDetermineFlutterOrDart.dart(),
              'packages/foo/bar/test': _FakeDetermineFlutterOrDart.dart(),
            };

            const modifiedFile = 'packages/foo/bar/test/foo_test.dart';

            final result = await testWatchCommand.findTest(
              testDirs,
              modifiedFile,
              returnTestFile: false,
            );

            expect(result, isNotNull);

            final (dir, tool) = result!;

            expect(dir, 'packages/foo/bar/test');
            expect(tool.isDart, isTrue);
          });
        });
      });

      group('returns file successfully', () {
        group('when root level', () {
          test('and modified is in lib', () async {
            fs.file('test/foo_test.dart').createSync(recursive: true);

            final testDirs = {
              'test': _FakeDetermineFlutterOrDart.dart(),
            };

            const modifiedFile = 'lib/foo.dart';

            final result = await testWatchCommand.findTest(
              testDirs,
              modifiedFile,
              returnTestFile: true,
            );

            expect(result, isNotNull);

            final (test, tool) = result!;

            expect(test, 'test/foo_test.dart');
            expect(tool.isDart, isTrue);
          });

          test('and modified is in test', () async {
            fs.file('test/foo_test.dart').createSync(recursive: true);

            final testDirs = {
              'test': _FakeDetermineFlutterOrDart.dart(),
            };

            const modifiedFile = 'test/foo_test.dart';

            final result = await testWatchCommand.findTest(
              testDirs,
              modifiedFile,
              returnTestFile: true,
            );

            expect(result, isNotNull);

            final (test, tool) = result!;

            expect(test, 'test/foo_test.dart');
            expect(tool.isDart, isTrue);
          });
        });

        test('finds the right file when many files are found', () async {
          fs.file('test/foo_test.dart').createSync(recursive: true);
          fs.file('test/utils/foo_test.dart').createSync(recursive: true);
          fs
              .file('test/something/else/foo_test.dart')
              .createSync(recursive: true);

          final testDirs = {
            'test': _FakeDetermineFlutterOrDart.dart(),
          };

          const expected = {
            'lib/foo.dart': 'test/foo_test.dart',
            'lib/utils/foo.dart': 'test/utils/foo_test.dart',
            'lib/something/else/foo.dart': 'test/something/else/foo_test.dart',
          };

          for (final entry in expected.entries) {
            final result = await testWatchCommand.findTest(
              testDirs,
              entry.key,
              returnTestFile: true,
            );

            expect(result, isNotNull);

            final (test, tool) = result!;

            expect(test, entry.value);
            expect(tool.isDart, isTrue);
          }
        });

        test('does not return test file when nothing found', () async {
          final testDirs = {
            'test': _FakeDetermineFlutterOrDart.dart(),
          };

          const modifiedFile = 'lib/foo.dart';

          final result = await testWatchCommand.findTest(
            testDirs,
            modifiedFile,
            returnTestFile: true,
          );

          expect(result, isNull);
        });

        test('does not return test dir when nothing found', () async {
          final testDirs = <String, DetermineFlutterOrDart>{
            'test': _FakeDetermineFlutterOrDart.dart(),
          };

          const modifiedFile = 'packages/ui/lib/foo.dart';

          final result = await testWatchCommand.findTest(
            testDirs,
            modifiedFile,
            returnTestFile: false,
          );

          expect(result, isNull);
        });
      });
    });
  });
}
