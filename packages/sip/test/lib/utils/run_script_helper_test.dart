import 'package:args/command_runner.dart';
import 'package:mason_logger/src/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/cwd.dart';
import 'package:sip_cli/domain/env_config.dart';
import 'package:sip_cli/domain/optional_flags.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/domain/variables.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/run_script_helper.dart';
import 'package:test/test.dart';

void main() {
  group(RunScriptHelper, () {
    group('#directory', () {
      test('should return the current directory if no scripts.yaml is found',
          () {
        final command = TestCommand();

        expect(command.directory, '/');
      });

      test('should return the directory of the nearest scripts.yaml', () {
        final command = TestCommand();

        when(() => command.scriptsYaml.nearest())
            .thenReturn('some/path/to/test/scripts.yaml');

        expect(command.directory, 'some/path/to/test');
      });
    });

    group('#validate', () {
      test('returns an exit code when no keys are provided', () async {
        final command = TestCommand();
        final result = await command.validate(null);

        expect(result, isA<ExitCode>());
      });

      test('returns an exit code when a private script is provided', () async {
        final command = TestCommand();
        final result = await command.validate(['_private']);

        expect(result, isA<ExitCode>());

        final result2 = await command.validate(['_private', 'public']);
        expect(result2, isA<ExitCode>());

        final result3 = await command.validate(['public', '_private']);
        expect(result3, isA<ExitCode>());
      });
    });

    group('#optionalFlags', () {
      test('should return an nothing', () {
        final command = TestCommand();

        expect(command.optionalFlags([]), OptionalFlags(const []));
      });

      test('should return a map with the provided flags', () {
        final command = TestCommand();

        expect(
          command.optionalFlags(['--verbose', 'true']),
          OptionalFlags(const ['--verbose', 'true']),
        );

        expect(
          command.optionalFlags(['some', 'script', '--verbose', 'true']),
          OptionalFlags(const ['--verbose', 'true']),
        );
      });
    });

    group('#getCommands', () {
      group('#env', () {
        test('should get the env config', () {
          final command = TestCommand();
          when(() => command.scriptsYaml.scripts()).thenReturn({
            'pub': {
              '(command)': 'echo "pub"',
              '(env)': {
                'file': 'some/path/to/test/.env',
                'command': 'echo "env"',
              }
            },
          });

          final result = command.getCommands(['pub'], listOut: false);

          expect(result.exitCode, isNull);
          final expectedConfig = EnvConfig(
            commands: {'echo "env"'},
            files: {'some/path/to/test/.env'},
          );

          expect(result.envConfig, expectedConfig);
        });

        test('should get the env config for the referenced script', () {
          final command = TestCommand();
          when(() => command.scriptsYaml.scripts()).thenReturn({
            'pub': {
              '(command)': r'{$other}',
              '(env)': {
                'file': 'some/path/to/test/.env',
                'command': 'pub env command',
              }
            },
            'other': {
              '(command)': 'echo "other"',
              '(env)': {
                'file': 'some/path/to/other/.env',
                'command': 'other env command',
              }
            },
          });

          final result = command.getCommands(['pub'], listOut: false);

          expect(result.exitCode, isNull);
          final expectedConfig = EnvConfig(
            commands: {
              'pub env command',
              'other env command',
            },
            files: {
              'some/path/to/test/.env',
              'some/path/to/other/.env',
            },
          );

          expect(result.envConfig, expectedConfig);
        });

        test('should remove duplicate env configs', () {
          final command = TestCommand();
          when(() => command.scriptsYaml.scripts()).thenReturn({
            'pub': {
              '(command)': r'{$other}',
              '(env)': {
                'file': 'some/path/to/test/.env',
                'command': 'pub env command',
              }
            },
            'other': {
              '(command)': 'echo "other"',
              '(env)': {
                'file': 'some/path/to/test/.env',
                'command': 'pub env command',
              }
            },
          });

          final result = command.getCommands(['pub'], listOut: false);

          expect(result.exitCode, isNull);
          final expectedConfig = EnvConfig(
            commands: {
              'pub env command',
            },
            files: {
              'some/path/to/test/.env',
            },
          );

          expect(result.envConfig, expectedConfig);
        });
      });

      test('should return the list of commands', () {
        final command = TestCommand();

        when(() => command.scriptsYaml.scripts()).thenReturn({
          'pub': 'echo "pub"',
        });

        final result = command.getCommands(['pub'], listOut: false);

        expect(result.exitCode, isNull);
        expect(result.commands, ['echo "pub"']);
      });

      test('should return an exit code when the script is not found', () {
        final command = TestCommand();
        final result = command.getCommands(['pub'], listOut: false);

        expect(result.exitCode, isA<ExitCode>());
        expect(result.commands, isNull);
      });

      test('should return an exit code when the script is empty', () {
        final command = TestCommand();
        when(() => command.scriptsYaml.scripts()).thenReturn({
          'pub': null,
        });

        final result = command.getCommands(['pub'], listOut: false);
        expect(result.exitCode, isA<ExitCode>());
        expect(result.commands, isNull);
      });

      test('should return an exit code with list option is provided', () {
        final command = TestCommand();

        when(() => command.scriptsYaml.scripts()).thenReturn({
          'pub': 'echo "pub"',
        });

        final result = command.getCommands(['pub'], listOut: true);

        expect(result.exitCode, isA<ExitCode>());
        expect(result.commands, isNull);
      });
    });

    group('#commandsToRun', () {
      test('should return the list of commands', () {
        final command = TestCommand();

        when(() => command.scriptsYaml.nearest())
            .thenReturn('some/path/to/test/scripts.yaml');

        when(() => command.scriptsYaml.scripts()).thenReturn({
          'pub': 'echo "pub"',
        });

        final result = command.commandsToRun(['pub'], listOut: false);

        expect(result.exitCode, isNull);
        expect(result.commands, isNotNull);

        final commandToRun = result.commands?.first;

        const expected = CommandToRun(
          command: 'echo "pub"',
          label: 'echo "pub"',
          workingDirectory: 'some/path/to/test',
          keys: ['pub'],
        );

        expect(commandToRun, expected);
      });

      test('should remove concurrent symbol when found', () {
        final command = TestCommand();

        when(() => command.scriptsYaml.nearest())
            .thenReturn('some/path/to/test/scripts.yaml');

        when(() => command.scriptsYaml.scripts()).thenReturn({
          'pub': '(+) echo "pub"',
        });

        final result = command.commandsToRun(['pub'], listOut: false);
        expect(result.exitCode, isNull);
        expect(result.commands?.map((e) => e.command), ['echo "pub"']);
        expect(result.commands?.map((e) => e.runConcurrently), [true]);
      });

      test('should remove extra concurrent symbols when found', () {
        final command = TestCommand();

        when(() => command.scriptsYaml.nearest())
            .thenReturn('some/path/to/test/scripts.yaml');

        when(() => command.scriptsYaml.scripts()).thenReturn({
          'pub': '(+) (+) echo "pub"',
        });

        final result = command.commandsToRun(['pub'], listOut: false);
        expect(result.exitCode, isNull);
        expect(result.commands?.map((e) => e.command), ['echo "pub"']);
        expect(result.commands?.map((e) => e.runConcurrently), [true]);
      });

      test('should return an exit code when the script is not found', () {
        final command = TestCommand();

        final result = command.commandsToRun(['pub'], listOut: false);
        expect(result.exitCode, isA<ExitCode>());
        expect(result.commands, isNull);
      });
    });
  });
}

class _MockScriptsYaml extends Mock implements ScriptsYaml {}

class _MockPubspecYaml extends Mock implements PubspecYaml {}

class _MockVariables extends Mock implements Variables {}

class _MockLogger extends Mock implements Logger {}

class _MockCWD extends Mock implements CWD {}

class TestCommand extends Command<ExitCode> with RunScriptHelper {
  TestCommand()
      : cwd = _MockCWD()..stub(),
        logger = _MockLogger()..stub(),
        scriptsYaml = _MockScriptsYaml()..stub(),
        pubspecYaml = _MockPubspecYaml()..stub() {
    addFlags();
  }
  @override
  final CWD cwd;

  @override
  final Logger logger;

  @override
  final ScriptsYaml scriptsYaml;

  final PubspecYaml pubspecYaml;

  @override
  Variables get variables => Variables(
        pubspecYaml: pubspecYaml,
        scriptsYaml: scriptsYaml,
        cwd: cwd,
      );

  @override
  String get name => '';

  @override
  String get description => '';
}

extension _CwdX on CWD {
  void stub() {
    final instance = this;

    when(() => instance.path).thenReturn('/');
  }
}

extension _LoggerX on Logger {
  void stub() {}
}

extension _ScriptsYamlX on ScriptsYaml {
  void stub() {}
}

extension _PubspecYamlX on PubspecYaml {
  void stub() {}
}
