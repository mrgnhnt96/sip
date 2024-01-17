import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:sip/commands/script_run_command.dart';
import 'package:sip/commands/script_run_many_command.dart';
import 'package:sip/setup/dependency_injection.dart';
import 'package:sip/src/version.dart';

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
    } on FormatException catch (e) {
      getIt<Logger>()
        ..err(e.message)
        ..info('\n$usage');
      return ExitCode.usage;
    } on UsageException catch (e) {
      getIt<Logger>()
        ..err(e.message)
        ..info('\n$usage');
      return ExitCode.usage;
    } catch (error) {
      getIt<Logger>().err('$error');
      return ExitCode.software;
    }
  }

  @override
  Future<ExitCode> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.wasParsed('version')) {
      getIt<Logger>().alert(packageVersion);

      return ExitCode.success;
    }

    final result = await super.runCommand(topLevelResults);

    return result ?? ExitCode.success;
  }
}
