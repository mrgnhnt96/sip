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

    group('runs gracefully', () {
      late ScriptRunCommand command;

      ScriptRunCommand prep() {
        final input = io.File(
          path.join(
            'test',
            'e2e',
            'run',
            'reference_concurrency',
            'inputs',
            'scripts.yaml',
          ),
        ).readAsStringSync();

        fs.file(ScriptsYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync(input);
        fs.file(PubspecYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync('');

        final command = ScriptRunCommand();

        return command;
      }

      setUp(() {
        command = prep();
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

      // fixes issue where reference does not contain any commands to run
      test('command: publish', () async {
        await command.run(['publish']);

        await Future<void>.delayed(Duration.zero);

        final scripts = [...bindings.scripts];

        const analyze = 'dart analyze --fatal-infos --fatal-warnings';

        final found = scripts.remove(analyze);

        expect(found, isTrue);

        expect(
          scripts,
          isNot(contains(analyze)),
          reason: 'analyze should only exist once',
        );
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
