import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:sip/commands/script_run_command.dart';
import 'package:sip/commands/script_run_many_command.dart';
import 'package:sip/src/version.dart';
import 'package:sip/utils/exit_code.dart';

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
  }

  @override
  Future<ExitCode> run(Iterable<String> args) async {
    try {
      final argResults = parse(args);

      final exitCode = await runCommand(argResults);

      return exitCode;
    } catch (error) {
      print('$error');
      return ExitCode.software;
    }
  }

  @override
  Future<ExitCode> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.wasParsed('version')) {
      print(packageVersion);

      return ExitCode.success;
    }

    final result = await super.runCommand(topLevelResults);

    return result ?? ExitCode.success;
  }
}
