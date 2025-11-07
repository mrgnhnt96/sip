import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/script_run_command.dart';
import 'package:sip_cli/domain/domain.dart';
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
          path.join('test', 'e2e', 'run', 'coverage', 'inputs', 'scripts.yaml'),
        ).readAsStringSync();

        fs.file(ScriptsYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync(input);
        fs.file(PubspecYaml.fileName)
          ..createSync(recursive: true)
          ..writeAsStringSync('');

        final runOneScript = RunOneScript(bindings: bindings, logger: logger);

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

      test('command: test', () async {
        await command.run(['test']);

        await Future<void>.delayed(const Duration(milliseconds: 100));

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

class _MockLogger extends Mock implements Logger {}
