import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/sip_runner.dart';
import 'package:sip_cli/src/commands/script_run_command.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/filter_type.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:test/test.dart';

import '../../../utils/test_scoped.dart';

void main() {
  group('lint e2e', () {
    late FileSystem fs;
    late _TestBindings bindings;

    setUp(() {
      bindings = _TestBindings();
      fs = MemoryFileSystem.test();

      final cwd = fs.directory(path.join('packages', 'sip'))
        ..createSync(recursive: true);
      fs.currentDirectory = cwd;
    });

    @isTest
    void test(String description, void Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        bindings: () => bindings,
      );
    }

    group('runs gracefully', () {
      late ScriptRunCommand command;
      late SipRunner runner;

      ScriptRunCommand prep() {
        final input = io.File(
          path.join('test', 'e2e', 'run', 'lint', 'inputs', 'scripts.yaml'),
        ).readAsStringSync();

        fs.file(ScriptsYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync(input);
        fs.file(PubspecYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync('');

        final command = ScriptRunCommand();

        runner = SipRunner(ogArgs: []);

        return command;
      }

      setUp(() {
        command = prep();
      });

      test('command: lint --package application', () async {
        await command.run(['lint', '--package', 'application']);

        await Future<void>.delayed(Duration.zero);

        expect(bindings.scripts.join('\n'), r'''
cd /packages/sip || exit 1

PKG_PATH="--package application"
PKG_PATH=$(echo "$PKG_PATH" | sed 's/^--package[ =]*//')
if [ -n "$PKG_PATH" ]; then
  dart analyze ./packages/$PKG_PATH --fatal-infos --fatal-warnings 
else
  dart analyze . --fatal-infos --fatal-warnings 
fi
''');
      });

      test('command: lint --package application --print', () async {
        await runner.run([
          'run',
          'lint',
          '--package',
          'application',
          '--print',
        ]);

        await Future<void>.delayed(Duration.zero);

        expect(bindings.scripts, isEmpty);
        verify(
          () => logger.write(r'''
PKG_PATH="--package application"
PKG_PATH=$(echo "$PKG_PATH" | sed 's/^--package[ =]*//')
if [ -n "$PKG_PATH" ]; then
  dart analyze ./packages/$PKG_PATH --fatal-infos --fatal-warnings 
else
  dart analyze . --fatal-infos --fatal-warnings 
fi'''),
        ).called(1);
      });
    });
  });
}

class _TestBindings implements Bindings {
  final List<String> scripts = [];

  @override
  Future<CommandResult> runScript(
    String script, {
    bool showOutput = false,
    FilterType? filterType,
    bool bail = false,
  }) async {
    scripts.addAll(script.split('\n'));

    return const CommandResult(exitCode: 0, output: '', error: '');
  }
}
