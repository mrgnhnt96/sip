// ignore_for_file: avoid_redundant_argument_values

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/script_run_command.dart';
import 'package:sip_cli/domain/domain.dart';
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

    ScriptRunCommand setupScripts() {
      final input = io.File(
        path.joinAll([
          'test',
          'e2e',
          'run',
          'complex_concurrency',
          'inputs',
          'scripts.yaml',
        ]),
      ).readAsStringSync();

      fs.file(ScriptsYaml.fileName)
        ..createSync(recursive: true)
        ..writeAsStringSync(input);
      fs.file(PubspecYaml.fileName)
        ..createSync(recursive: true)
        ..writeAsStringSync('');

      return ScriptRunCommand(
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
    }

    test('should run complex concurrency', () async {
      final command = setupScripts();

      await command.run(['test-suite']);
      {
        final results = <List<CommandToRun>>[];

        verify(
          () => runManyScripts.run(
            commands: any(
              named: 'commands',
              that: isA<List<CommandToRun>>().having(
                (items) {
                  return items;
                },
                'has correct scripts',
                (Object? items) {
                  results.add(items! as List<CommandToRun>);
                  return true;
                },
              ),
            ),
            sequentially: false,
            bail: false,
            label: any(named: 'label'),
            maxAttempts: any(named: 'maxAttempts'),
            retryAfter: any(named: 'retryAfter'),
          ),
        ).called(1);

        expect(results.first, hasLength(21));
      }

      {
        final results = <CommandToRun>[];

        verify(
          () => runOneScript.run(
            command: any(
              named: 'command',
              that: isA<CommandToRun>().having(
                (items) {
                  return items;
                },
                'has correct script',
                (Object? items) {
                  results.add(items! as CommandToRun);

                  return true;
                },
              ),
            ),
            showOutput: any(named: 'showOutput'),
            maxAttempts: any(named: 'maxAttempts'),
            retryAfter: any(named: 'retryAfter'),
          ),
        ).called(2);
      }
    });
  });
}

class _MockBindings extends Mock implements Bindings {}

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

class _MockRunOneScript extends Mock implements RunOneScript {}

class _MockRunManyScript extends Mock implements RunManyScripts {}
