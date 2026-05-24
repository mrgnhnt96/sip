import 'package:mocktail/mocktail.dart';
import 'package:platform/platform.dart';
import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/deps/platform.dart';
import 'package:sip_cli/src/utils/shell_script.dart';
import 'package:test/test.dart';

class _MockPlatform extends Mock implements Platform {}

void main() {
  group('ShellScript', () {
    late _MockPlatform mockPlatform;

    setUp(() {
      mockPlatform = _MockPlatform();
    });

    Future<void> withPlatform(void Function() fn) async {
      await runScoped(
        values: {platformProvider.overrideWith(() => mockPlatform)},
        () async => fn(),
      );
    }

    group('usesCmdShell', () {
      test('unix never uses cmd', () {
        expect(usesCmdShell(isWindows: false), isFalse);
        expect(usesCmdShell(isWindows: false, msystem: 'MINGW64'), isFalse);
      });

      test('native windows uses cmd', () {
        expect(usesCmdShell(isWindows: true), isTrue);
        expect(usesCmdShell(isWindows: true, msystem: ''), isTrue);
      });

      test('windows Git Bash uses posix shell', () {
        expect(usesCmdShell(isWindows: true, msystem: 'MINGW64'), isFalse);
      });
    });

    group('resolvePosixShellOnWindows', () {
      test('prefers EXEPATH bash.exe', () {
        final seen = <String>[];

        final resolved = resolvePosixShellOnWindows(
          exepath: r'C:\Program Files\Git\bin',
          exists: (path) {
            seen.add(path);
            return path == r'C:\Program Files\Git\bin\bash.exe';
          },
        );

        expect(resolved, r'C:\Program Files\Git\bin\bash.exe');
        expect(seen.first, r'C:\Program Files\Git\bin\bash.exe');
      });

      test('falls back to usr/bin/bash.exe under EXEPATH', () {
        final resolved = resolvePosixShellOnWindows(
          exepath: r'C:\Program Files\Git\bin',
          exists: (path) => path == r'C:\Program Files\Git\usr\bin\bash.exe',
        );

        expect(resolved, r'C:\Program Files\Git\usr\bin\bash.exe');
      });

      test('falls back to ProgramFiles Git install', () {
        final resolved = resolvePosixShellOnWindows(
          programFiles: r'C:\Program Files',
          exists: (path) => path == r'C:\Program Files\Git\usr\bin\bash.exe',
        );

        expect(resolved, r'C:\Program Files\Git\usr\bin\bash.exe');
      });
    });

    group('on unix', () {
      setUp(() {
        when(() => mockPlatform.isWindows).thenReturn(false);
      });

      test('changeDirectory uses bash cd', () async {
        await withPlatform(() {
          expect(
            ShellScript.changeDirectory('/project/packages/foo'),
            'cd "/project/packages/foo" || exit 1',
          );
        });
      });

      test('setVariable uses export', () async {
        await withPlatform(() {
          expect(
            ShellScript.setVariable('GITHUB_ACTIONS', 'true'),
            'export GITHUB_ACTIONS=true',
          );
        });
      });

      test('variableSeparator joins exports with newlines', () async {
        await withPlatform(() {
          expect(ShellScript.variableSeparator, '\n');
          expect(
            [
              ShellScript.setVariable('FOO', 'bar'),
              ShellScript.setVariable('BAZ', 'qux'),
            ].join(ShellScript.variableSeparator),
            'export FOO=bar\nexport BAZ=qux',
          );
        });
      });

      test('joinCommands uses blank lines', () async {
        await withPlatform(() {
          expect(
            ShellScript.joinCommands([
              'cd "/project" || exit 1',
              'export FOO=bar',
              'dart pub get',
            ]),
            'cd "/project" || exit 1\n\nexport FOO=bar\n\ndart pub get',
          );
        });
      });
    });

    group('on windows', () {
      setUp(() {
        when(() => mockPlatform.isWindows).thenReturn(true);
      });

      test('changeDirectory uses cmd cd /d', () async {
        await withPlatform(() {
          expect(
            ShellScript.changeDirectory(r'C:\project\packages\foo'),
            'cd /d "C:/project/packages/foo" || exit /b 1',
          );
        });
      });

      test(
        'changeDirectory avoids backslash escape sequences in paths',
        () async {
          await withPlatform(() {
            expect(
              ShellScript.changeDirectory(
                r'D:\a\sip\sip\test\integration\smoke',
              ),
              'cd /d "D:/a/sip/sip/test/integration/smoke" || exit /b 1',
            );
          });
        },
      );

      test('setVariable uses set', () async {
        await withPlatform(() {
          expect(
            ShellScript.setVariable('GITHUB_ACTIONS', 'true'),
            'set "GITHUB_ACTIONS=true"',
          );
        });
      });

      test('variableSeparator joins set commands with &&', () async {
        await withPlatform(() {
          expect(ShellScript.variableSeparator, ' && ');
          expect(
            [
              ShellScript.setVariable('FOO', 'bar'),
              ShellScript.setVariable('BAZ', 'qux'),
            ].join(ShellScript.variableSeparator),
            'set "FOO=bar" && set "BAZ=qux"',
          );
        });
      });

      test('joinCommands chains with &&', () async {
        await withPlatform(() {
          expect(
            ShellScript.joinCommands([
              'cd /d "C:/project" || exit /b 1',
              'set "FOO=bar"',
              'dart pub get',
            ]),
            'cd /d "C:/project" || exit /b 1 && set "FOO=bar" && dart pub get',
          );
        });
      });

      test('joinCommands flattens multiline commands', () async {
        await withPlatform(() {
          expect(
            ShellScript.joinCommands([
              'cd /d "C:/project" || exit /b 1',
              // ignore: no_adjacent_strings_in_list
              r'cd packages\foo'
                  '\n'
                  'dart pub get',
            ]),
            r'cd /d "C:/project" || exit /b 1 && cd packages\foo && dart pub get',
          );
        });
      });
    });
  });
}
