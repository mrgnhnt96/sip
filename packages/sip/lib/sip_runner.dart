// ignore_for_file: cascade_invocations

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:sip_cli/commands/list_command.dart';
import 'package:sip_cli/commands/pub_command.dart';
import 'package:sip_cli/commands/script_run_command.dart';
import 'package:sip_cli/commands/test_command/test_command.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/src/version.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_script_runner/domain/domain.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

/// The command runner for the sip command line application
class SipRunner extends CommandRunner<ExitCode> {
  SipRunner({
    required ScriptsYaml scriptsYaml,
    required PubspecLock pubspecLock,
    required PubspecYaml pubspecYaml,
    required Variables variables,
    required Bindings bindings,
    required FindFile findFile,
  }) : super(
          'sip',
          'A command line application to handle mono-repos in dart',
        ) {
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the current version',
    );

    argParser.addFlag(
      'loud',
      negatable: false,
      hide: true,
      help: 'Prints verbose output',
    );

    addCommand(
      ScriptRunCommand(
        scriptsYaml: scriptsYaml,
        variables: variables,
        bindings: bindings,
      ),
    );
    addCommand(
      PubCommand(
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
      ),
    );
    addCommand(
      ListCommand(
        scriptsYaml: scriptsYaml,
      ),
    );
    addCommand(
      TestCommand(
        pubspecYaml: pubspecYaml,
        pubspecLock: pubspecLock,
        findFile: findFile,
        bindings: bindings,
      ),
    );
  }

  @override
  Future<ExitCode> run(Iterable<String> args) async {
    try {
      final argResults = parse(args);

      if (argResults['loud'] == true) {
        getIt<SipConsole>().enableVerbose();
      }

      final exitCode = await runCommand(argResults);

      return exitCode;
    } catch (error) {
      getIt<SipConsole>().e('$error');
      return ExitCode.software;
    }
  }

  @override
  Future<ExitCode> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.wasParsed('version')) {
      getIt<SipConsole>().l(packageVersion);

      return ExitCode.success;
    }

    final result = await super.runCommand(topLevelResults);

    getIt<SipConsole>().d('Ran sip command, exit code: $result');

    return result ?? ExitCode.success;
  }
}
