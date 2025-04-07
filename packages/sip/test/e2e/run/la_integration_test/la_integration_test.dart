import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/script_run_command.dart';
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_result.dart';
import 'package:sip_cli/domain/domain.dart';
import 'package:sip_cli/domain/filter_type.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/domain/variables.dart';
import 'package:test/test.dart';

import '../../../utils/stub_logger.dart';

void main() {
  group('env files e2e', () {
    late FileSystem fs;
    late _TestBindings bindings;
    late Logger logger;

    setUp(() {
      bindings = _TestBindings();
      logger = _MockLogger()..stub();

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
            'la_integration_test',
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

        final runOneScript = RunOneScript(
          bindings: bindings,
          logger: logger,
        );

        final command = ScriptRunCommand(
          bindings: bindings,
          cwd: CWDImpl(fs: fs),
          logger: logger,
          scriptsYaml: ScriptsYamlImpl(fs: fs),
          variables: Variables(
            cwd: CWDImpl(fs: fs),
            pubspecYaml: PubspecYamlImpl(fs: fs),
            scriptsYaml: ScriptsYamlImpl(fs: fs),
          ),
          runManyScripts: RunManyScripts(
            bindings: bindings,
            logger: logger,
            runOneScript: runOneScript,
          ),
          runOneScript: runOneScript,
        );

        return command;
      }

      setUp(() {
        command = prep();
      });

      // fixes issue where reference does not contain any commands to run
      test('command: test integration android', () async {
        await command.run(['test', 'integration', 'android']);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(
          bindings.scripts,
          [
            'cd /packages/sip || exit 1',
            '',
            r'C=$(sh ./scripts/integration_test.sh --platform="android"); echo $C; $C',
            '',
          ],
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

    return const CommandResult(
      exitCode: 0,
      output: '',
      error: '',
    );
  }
}

class _MockLogger extends Mock implements Logger {}
