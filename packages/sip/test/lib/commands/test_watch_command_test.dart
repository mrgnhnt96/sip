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

    group('#findTestDir', () {
      group('return successfully', () {
        group('when root level', () {
          test(
            'and modified is in lib',
            () {
              final testDirs = {
                'test': _FakeDetermineFlutterOrDart.dart(),
              };

              const modifiedFile = 'lib/foo.dart';

              final result = testWatchCommand.findTestDir(
                testDirs,
                modifiedFile,
              );

              expect(result, isNotNull);

              final (dir, tool) = result!;

              expect(dir, 'test');
              expect(tool.isDart, isTrue);
            },
          );

          test(
            'and modified is in test',
            () {
              final testDirs = {
                'test': _FakeDetermineFlutterOrDart.dart(),
              };

              const modifiedFile = 'test/foo_test.dart';

              final result = testWatchCommand.findTestDir(
                testDirs,
                modifiedFile,
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
            () {
              final testDirs = {
                'test': _FakeDetermineFlutterOrDart.dart(),
                'packages/foo/test': _FakeDetermineFlutterOrDart.dart(),
              };

              const modifiedFile = 'packages/foo/lib/foo.dart';

              final result = testWatchCommand.findTestDir(
                testDirs,
                modifiedFile,
              );

              expect(result, isNotNull);

              final (dir, tool) = result!;

              expect(dir, 'packages/foo/test');
              expect(tool.isDart, isTrue);
            },
          );

          test(
            'and modified is in test',
            () {
              final testDirs = {
                'test': _FakeDetermineFlutterOrDart.dart(),
                'packages/foo/test': _FakeDetermineFlutterOrDart.dart(),
              };

              const modifiedFile = 'packages/foo/test/foo_test.dart';

              final result = testWatchCommand.findTestDir(
                testDirs,
                modifiedFile,
              );

              expect(result, isNotNull);

              final (dir, tool) = result!;

              expect(dir, 'packages/foo/test');
              expect(tool.isDart, isTrue);
            },
          );

          test('when there are similar starting paths', () {
            final testDirs = {
              'test': _FakeDetermineFlutterOrDart.dart(),
              'packages/foo/test': _FakeDetermineFlutterOrDart.dart(),
              'packages/foo/bar/test': _FakeDetermineFlutterOrDart.dart(),
            };

            const modifiedFile = 'packages/foo/bar/test/foo_test.dart';

            final result = testWatchCommand.findTestDir(
              testDirs,
              modifiedFile,
            );

            expect(result, isNotNull);

            final (dir, tool) = result!;

            expect(dir, 'packages/foo/bar/test');
            expect(tool.isDart, isTrue);
          });
        });
      });
    });
  });
}
