import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/run_script_helper.dart';
import 'package:sip_script_runner/domain/optional_flags.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:test/test.dart';

import '../../utils/setup_testing_dependency_injection.dart';

class _FakeCommand extends Command<ExitCode> with RunScriptHelper {
  _FakeCommand({
    required this.scriptsYaml,
    required this.variables,
  }) {
    addFlags();
  }

  ArgResults? argResults;

  @override
  final ScriptsYaml scriptsYaml;

  @override
  final Variables variables;

  @override
  String get description => '';

  @override
  String get name => '';
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

class _FakeVariables implements Variables {
  @override
  CWD get cwd => throw UnimplementedError();

  @override
  Map<String, String?> populate() {
    throw UnimplementedError();
  }

  @override
  PubspecYaml get pubspecYaml => throw UnimplementedError();

  @override
  List<String> replace(
    Script script,
    ScriptsConfig config, {
    OptionalFlags? flags,
  }) {
    return script.commands;
  }

  @override
  ScriptsYaml get scriptsYaml => throw UnimplementedError();
}

void main() {
  late _FakeCommand command;
  late ArgParser argParser;

  setUp(() {
    argParser = ArgParser()..addFlag('list');

    setupTestingDependencyInjection();

    command = _FakeCommand(
      scriptsYaml: _FakeScriptsYaml(),
      variables: _FakeVariables(),
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
        expect(command.optionalFlags([]), OptionalFlags([]));
      });

      test('should return a map with the provided flags', () {
        expect(
          command.optionalFlags(['--verbose', 'true']),
          OptionalFlags(['--verbose', 'true']),
        );

        expect(
          command.optionalFlags(['some', 'script', '--verbose', 'true']),
          OptionalFlags(['--verbose', 'true']),
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
        final expected = CommandToRun(
          command: 'echo "pub"',
          label: 'echo "pub"',
          workingDirectory: 'some/path/to/test',
        );

        expect(commandToRun.command, expected.command);
        expect(commandToRun.label, expected.label);
        expect(commandToRun.workingDirectory, expected.workingDirectory);
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
