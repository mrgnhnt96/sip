// ignore_for_file: avoid_redundant_argument_values

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/script_run_command.dart';
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_result.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/domain.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/domain/variables.dart';
import 'package:test/test.dart';

void main() {
  group('concurrency groups test', () {
    late FileSystem fs;
    late Bindings bindings;
    late Logger logger;
    late RunOneScript runOneScript;
    late RunManyScripts runManyScripts;

    setUpAll(() {
      registerFallbackValue(
        const CommandToRun(command: '__fake__', workingDirectory: '', keys: []),
      );
    });

    setUp(() {
      bindings = _MockBindings();
      logger = _MockLogger();
      final progress = _MockProgress();
      when(() => logger.level).thenReturn(Level.quiet);
      when(() => logger.progress(any())).thenReturn(progress);

      runOneScript = _MockRunOneScript();
      runManyScripts = _MockRunManyScript();

      when(() => runManyScripts.runOneScript).thenReturn(runOneScript);
      when(
        () => runOneScript.run(
          command: any(named: 'command'),
          showOutput: any(named: 'showOutput'),
          filter: any(named: 'filter'),
          maxAttempts: any(named: 'maxAttempts'),
          retryAfter: any(named: 'retryAfter'),
        ),
      ).thenAnswer(
        (invocation) async => const CommandResult(
          exitCode: 0,
          output: '',
          error: '',
        ),
      );
      when(
        () => runManyScripts.run(
          commands: any(named: 'commands'),
          sequentially: any(named: 'sequentially'),
          bail: any(named: 'bail'),
          label: any(named: 'label'),
          maxAttempts: any(named: 'maxAttempts'),
          retryAfter: any(named: 'retryAfter'),
        ),
      ).thenAnswer(
        (invocation) async => [
          if (invocation.namedArguments[#commands]
              case final List<CommandToRun> commands)
            for (final command in commands)
              CommandResult(
                exitCode: 0,
                output: command.command,
                error: '',
              ),
        ],
      );

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
          'concurrency_groups',
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
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
      );

      await command.run(['combined']);

      verify(
        () => runManyScripts.run(
          commands: any(
            named: 'commands',
            that: isA<List<CommandToRun>>().having(
              (items) {
                return items;
              },
              'has correct scripts',
              [
                ...[
                  'wait 1',
                  'wait 2',
                  'wait 3',
                ].map(
                  (e) => CommandToRun(
                    command: e,
                    workingDirectory: '/packages/sip',
                    keys: const ['combined'],
                    runPreviousFirst: true,
                    bail: false,
                  ),
                ),
              ],
            ),
          ),
          sequentially: true,
          bail: false,
          label: any(named: 'label'),
          maxAttempts: any(named: 'maxAttempts'),
          retryAfter: any(named: 'retryAfter'),
        ),
      ).called(1);

      // verify calls to the multi and single script runners
      expect(true, isFalse);
    });
  });
}

class _MockBindings extends Mock implements Bindings {}

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

class _MockRunOneScript extends Mock implements RunOneScript {}

class _MockRunManyScript extends Mock implements RunManyScripts {}
