import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/src/domain/env_config.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/utils/run_script_helper.dart';
import 'package:sip_cli/src/utils/working_directory.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group(RunScriptHelper, () {
    late ScriptsYaml scriptsYaml;
    late PubspecYaml pubspecYaml;
    late FileSystem fs;

    setUp(() {
      fs = MemoryFileSystem.test();
      scriptsYaml = _MockScriptsYaml();
      pubspecYaml = _MockPubspecYaml();

      fs.file(fs.path.join('some', 'path', 'to', 'test', '.env'))
        ..createSync(recursive: true)
        ..writeAsStringSync('TEST_VAR=test');
    });

    @isTest
    void test(String description, FutureOr<void> Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        scriptsYaml: () => scriptsYaml,
        pubspecYaml: () => pubspecYaml,
      );
    }

    group('#directory', () {
      test(
        'should return the current directory if no scripts.yaml is found',
        () {
          final command = _TestCommand();

          expect(command.directory, '/');
        },
      );

      test('should return the directory of the nearest scripts.yaml', () {
        final command = _TestCommand();

        when(scriptsYaml.nearest).thenReturn('some/path/to/test/scripts.yaml');

        expect(command.directory, 'some/path/to/test');
      });
    });

    group('#validate', () {
      test('returns an exit code when no keys are provided', () async {
        final command = _TestCommand();
        final result = await command.validate(null);

        expect(result, isA<ExitCode>());
      });

      test('returns an exit code when a private script is provided', () async {
        final command = _TestCommand();
        final result = await command.validate(['_private']);

        expect(result, isA<ExitCode>());

        final result2 = await command.validate(['_private', 'public']);
        expect(result2, isA<ExitCode>());

        final result3 = await command.validate(['public', '_private']);
        expect(result3, isA<ExitCode>());
      });
    });

    group('#getCommands', () {
      group('#env', () {
        test('should get the env config', () {
          final command = _TestCommand();

          when(scriptsYaml.scripts).thenReturn({
            'pub': {
              '(command)': 'echo "pub"',
              '(env)': {
                'file': 'some/path/to/test/.env',
                'command': 'echo "env"',
              },
            },
          });

          final (resolveScript, exitCode) = command.getCommands([
            'pub',
          ], listOut: false);

          expect(exitCode, isNull);
          const expectedConfig = EnvConfig(
            commands: ['echo "env"'],
            files: ['some/path/to/test/.env'],
            variables: {'TEST_VAR': 'test'},
          );

          expect(resolveScript?.envConfig!.commands, expectedConfig.commands);
          expect(resolveScript?.envConfig!.files, expectedConfig.files);
          expect(resolveScript?.envConfig!.variables, expectedConfig.variables);
        });

        test('should remove duplicate env configs', () {
          final command = _TestCommand();
          when(scriptsYaml.scripts).thenReturn({
            'pub': {
              '(command)': r'{$other}',
              '(env)': {
                'file': 'some/path/to/test/.env',
                'command': 'pub env command',
              },
            },
            'other': {
              '(command)': 'echo "other"',
              '(env)': {
                'file': 'some/path/to/test/.env',
                'command': 'pub env command',
              },
            },
          });

          final (resolveScript, exitCode) = command.getCommands([
            'pub',
          ], listOut: false);

          expect(exitCode, isNull);
          const expectedConfig = EnvConfig(
            commands: ['pub env command'],
            files: ['some/path/to/test/.env'],
          );

          expect(resolveScript?.envConfig!.commands, expectedConfig.commands);
          expect(resolveScript?.envConfig!.files, expectedConfig.files);
          expect(resolveScript?.envConfig!.variables, expectedConfig.variables);
        });
      });

      test('should return the list of commands', () {
        final command = _TestCommand();

        when(scriptsYaml.scripts).thenReturn({'pub': 'echo "pub"'});

        final (resolveScript, exitCode) = command.getCommands([
          'pub',
        ], listOut: false);

        expect(exitCode, isNull);
        expect(
          (resolveScript!.commands.single as ScriptToRun).exe,
          'echo "pub"',
        );
      });

      test('should return an exit code when the script is not found', () {
        final command = _TestCommand();
        final (resolveScript, exitCode) = command.getCommands([
          'pub',
        ], listOut: false);

        expect(exitCode, isA<ExitCode>());
        expect(resolveScript, isNull);
      });

      test('should return an exit code when the script is empty', () {
        final command = _TestCommand();
        when(scriptsYaml.scripts).thenReturn({'pub': null});

        final (resolveScript, exitCode) = command.getCommands([
          'pub',
        ], listOut: false);
        expect(exitCode, isA<ExitCode>());
        expect(resolveScript, isNull);
      });

      test('should return an exit code with list option is provided', () {
        final command = _TestCommand();

        when(scriptsYaml.scripts).thenReturn({'pub': 'echo "pub"'});

        final (resolveScript, exitCode) = command.getCommands([
          'pub',
        ], listOut: true);

        expect(exitCode, isA<ExitCode>());
        expect(resolveScript, isNull);
      });

      test('should resolve multiple references', () {
        final command = _TestCommand();

        when(scriptsYaml.scripts).thenReturn({
          'test-domain': r'''
cd packages/domain
{$test:_test}
''',
          'test': {
            '_clear-coverage': 'clear-coverage',
            '_format-coverage': 'format-coverage',
            '_open-coverage': 'open-coverage',
            '_test': [
              r'{$test:_clear-coverage}',
              'sip test {--coverage}',
              r'{$test:_format-coverage}',
              r'{$test:_open-coverage}',
            ],
          },
        });

        final (resolveScript, exitCode) = command.getCommands([
          'test-domain',
        ], listOut: false);

        expect(exitCode, isNull);
        expect(resolveScript?.commands, hasLength(4));
        expect((resolveScript!.commands.first as ScriptToRun).exe.split('\n'), [
          'cd packages/domain',
          'clear-coverage',
        ]);
        expect(
          (resolveScript.commands.elementAt(1) as ScriptToRun).exe.split('\n'),
          ['cd packages/domain', 'sip test'],
        );
        expect(
          (resolveScript.commands.elementAt(2) as ScriptToRun).exe.split('\n'),
          ['cd packages/domain', 'format-coverage'],
        );
        expect(
          (resolveScript.commands.elementAt(3) as ScriptToRun).exe.split('\n'),
          ['cd packages/domain', 'open-coverage'],
        );
      });
    });
  });
}

class _MockScriptsYaml extends Mock implements ScriptsYaml {}

class _MockPubspecYaml extends Mock implements PubspecYaml {}

class _TestCommand with RunScriptHelper, WorkingDirectory {
  _TestCommand();
}
