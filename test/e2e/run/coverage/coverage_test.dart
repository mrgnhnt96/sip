import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/commands/script_run_command.dart';
import 'package:sip_cli/src/domain/bindings.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/filter_type.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:test/test.dart';

import '../../../utils/test_scoped.dart';

void main() {
  group('env files e2e', () {
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

      ScriptRunCommand prep() {
        final input = io.File(
          path.join('test', 'e2e', 'run', 'coverage', 'inputs', 'scripts.yaml'),
        ).readAsStringSync();

        fs.file(ScriptsYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync(input);
        fs.file(PubspecYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync('');

        const command = ScriptRunCommand();

        return command;
      }

      setUp(() {
        command = prep();
      });

      test('command: test', () async {
        await command.run(['test']);

        expect(bindings.scripts, [
          'cd /packages/sip || exit 1',
          '',
          'dart test',
          '',
        ]);
      });

      test('command: test --coverage', () async {
        await command.run(['test', '--coverage']);

        expect(bindings.scripts, [
          'cd /packages/sip || exit 1',
          '',
          'dart test --coverage',
          '',
        ]);
      });

      test('command: test --coverage=banana', () async {
        await command.run(['test', '--coverage=banana']);

        expect(bindings.scripts, [
          'cd /packages/sip || exit 1',
          '',
          'dart test --coverage=banana',
          '',
        ]);
      });

      test('command: test --coverage monkey', () async {
        await command.run(['test', '--coverage', 'monkey']);

        expect(bindings.scripts, [
          'cd /packages/sip || exit 1',
          '',
          'dart test --coverage monkey',
          '',
        ]);
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
