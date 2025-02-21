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
  group('build runner e2e', () {
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

    test('runs gracefully', () async {
      final input = io.File(
        path.join(
          'test',
          'e2e',
          'run',
          'build_runner',
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

      await command.run(['build_runner', 'b']);

      expect(
        bindings.scripts,
        [
          'cd /packages/sip || exit 1',
          '',
          'dart run build_runner clean;',
          'dart run build_runner build --delete-conflicting-outputs',
          '',
        ],
      );
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
  }) {
    scripts.addAll(script.split('\n'));
    return Future.value(
      const CommandResult(
        exitCode: 0,
        output: '',
        error: '',
      ),
    );
  }
}

class _MockLogger extends Mock implements Logger {}
