import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/src/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/cwd.dart';
import 'package:sip_cli/domain/optional_flags.dart';
import 'package:sip_cli/domain/script.dart';
import 'package:sip_cli/domain/scripts_config.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/domain/variables.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/run_script_helper.dart';
import 'package:test/test.dart';

class _FakeCommand extends Command<ExitCode> with RunScriptHelper {
  _FakeCommand({
    required this.scriptsYaml,
    required this.variables,
    required this.cwd,
    required this.logger,
  }) {
    addFlags();
  }

  @override
  ArgResults? argResults;

  @override
  final ScriptsYaml scriptsYaml;

  @override
  final Variables variables;

  @override
  String get description => '';

  @override
  String get name => '';

  @override
  final CWD cwd;

  @override
  final Logger logger;
}

class _FakeScriptsYaml implements ScriptsYaml {
  String? nearestFile;
  @override
  String? nearest() {
    return nearestFile;
  }

  Map<String, dynamic>? content;

  @override
  Map<String, dynamic>? scripts() => content ?? {};

  @override
  String? retrieveContent() {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic>? parse() => {};

  @override
  Map<String, dynamic>? variables() => {};
}

class _FakeVariables extends Fake implements Variables {
  @override
  List<String> replace(
    Script script,
    ScriptsConfig config, {
    OptionalFlags? flags,
  }) {
    return script.commands;
  }
}

class _MockLogger extends Mock implements Logger {}

class _FakeCWD extends Fake implements CWD {
  @override
  String get path => '/';
}

void main() {
  late _FakeCommand command;
  late ArgParser argParser;

  setUp(() {
    argParser = ArgParser()..addFlag('list');

    command = _FakeCommand(
      scriptsYaml: _FakeScriptsYaml(),
      variables: _FakeVariables(),
      cwd: _FakeCWD(),
      logger: _MockLogger(),
    );
  });

  group('$RunScriptHelper', () {
    group('#directory', () {
      test('should return the current directory if no scripts.yaml is found',
          () {
        expect(command.directory, '/');
      });

      test('should return the directory of the nearest scripts.yaml', () {
        (command.scriptsYaml as _FakeScriptsYaml).nearestFile =
            'some/path/to/test/scripts.yaml';

        expect(command.directory, 'some/path/to/test');
      });
    });

    group('#validate', () {
      test('returns an exit code when no keys are provided', () async {
        final result = await command.validate(null);
        expect(result, isA<ExitCode>());
      });

      test('returns an exit code when a private script is provided', () async {
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
        expect(command.optionalFlags([]), OptionalFlags(const []));
      });

      test('should return a map with the provided flags', () {
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
      late ArgResults argResults;

      setUp(() {
        argResults = argParser.parse([]);
      });

      test('should return the list of commands', () {
        (command.scriptsYaml as _FakeScriptsYaml).content = {
          'pub': 'echo "pub"',
        };

        final (exitCode, commands, _) =
            command.getCommands(['pub'], argResults);
        expect(exitCode, isNull);
        expect(commands, ['echo "pub"']);
      });

      test('should return an exit code when the script is not found', () {
        final (exitCode, commands, _) =
            command.getCommands(['pub'], argResults);
        expect(exitCode, isA<ExitCode>());
        expect(commands, isNull);
      });

      test('should return an exit code when the script is empty', () {
        (command.scriptsYaml as _FakeScriptsYaml).content = {
          'pub': null,
        };

        final (exitCode, commands, _) =
            command.getCommands(['pub'], argResults);
        expect(exitCode, isA<ExitCode>());
        expect(commands, isNull);
      });

      test('should return an exit code with list option is provided', () {
        command.argResults = command.argParser.parse(['--list']);

        final argResults = command.argResults!;

        (command.scriptsYaml as _FakeScriptsYaml).content = {
          'pub': 'echo "pub"',
        };

        final (exitCode, commands, _) =
            command.getCommands(['pub'], argResults);

        expect(exitCode, isA<ExitCode>());
        expect(commands, isNull);
      });
    });

    group('#commandsToRun', () {
      late ArgResults argResults;

      setUp(() {
        argResults = argParser.parse([]);
      });

      test('should return the list of commands', () {
        (command.scriptsYaml as _FakeScriptsYaml).nearestFile =
            'some/path/to/test/scripts.yaml';

        (command.scriptsYaml as _FakeScriptsYaml).content = {
          'pub': 'echo "pub"',
        };

        final (exitCode, commands, _) =
            command.commandsToRun(['pub'], argResults);
        expect(exitCode, isNull);

        expect(commands, isNotNull);

        final commandToRun = commands!.first;
        const expected = CommandToRun(
          command: 'echo "pub"',
          label: 'echo "pub"',
          workingDirectory: 'some/path/to/test',
          keys: ['pub'],
        );

        expect(commandToRun, expected);
      });

      test('should remove concurrent symbol when found', () {
        (command.scriptsYaml as _FakeScriptsYaml).nearestFile =
            'some/path/to/test/scripts.yaml';

        (command.scriptsYaml as _FakeScriptsYaml).content = {
          'pub': '(+) echo "pub"',
        };

        final (exitCode, commands, _) =
            command.commandsToRun(['pub'], argResults);
        expect(exitCode, isNull);
        expect(commands?.map((e) => e.command), ['echo "pub"']);
        expect(commands?.map((e) => e.runConcurrently), [true]);
      });

      test('should remove extra concurrent symbols when found', () {
        (command.scriptsYaml as _FakeScriptsYaml).nearestFile =
            'some/path/to/test/scripts.yaml';

        (command.scriptsYaml as _FakeScriptsYaml).content = {
          // This can happen if the user references an already concurrent script
          'pub': '(+) (+) echo "pub"',
        };

        final (exitCode, commands, _) =
            command.commandsToRun(['pub'], argResults);
        expect(exitCode, isNull);
        expect(commands?.map((e) => e.command), ['echo "pub"']);
        expect(commands?.map((e) => e.runConcurrently), [true]);
      });

      test('should return an exit code when the script is not found', () {
        final (exitCode, commands, _) =
            command.commandsToRun(['pub'], argResults);
        expect(exitCode, isA<ExitCode>());
        expect(commands, isNull);
      });
    });
  });
}
