import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:sip_cli/commands/list_command.dart';
import 'package:sip_cli/commands/pub_command.dart';
import 'package:sip_cli/commands/script_run_command.dart';
import 'package:sip_cli/commands/script_run_many_command.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/src/version.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_console/sip_console.dart';

/// The command runner for the sip command line application
class SipRunner extends CommandRunner<ExitCode> {
  SipRunner()
      : super(
          'sip',
          'A command line application to handle mono-repos in dart',
        ) {
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the current version',
    );

    addCommand(ScriptRunCommand());
    addCommand(ScriptRunManyCommand());
    addCommand(PubCommand());
    addCommand(ListCommand());
  }

  @override
  Future<ExitCode> run(Iterable<String> args) async {
    try {
      final argResults = parse(args);

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

    return result ?? ExitCode.success;
  }
}
