import 'package:args/command_runner.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/cwd_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/domain/scripts_yaml_impl.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';
import 'package:sip_cli/utils/run_script_helper.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

/// The command to run a script
class ScriptRunCommand extends Command<ExitCode> with RunScriptHelper {
  ScriptRunCommand({
    this.scriptsYaml = const ScriptsYamlImpl(),
    this.variables = const Variables(
      pubspecYaml: PubspecYamlImpl(),
      scriptsYaml: ScriptsYamlImpl(),
      cwd: CWDImpl(),
    ),
    this.bindings = const BindingsImpl(),
  }) {
    addFlags();

    argParser.addFlag(
      'bail',
      negatable: false,
      help: 'Stop on first error',
    );
  }

  final ScriptsYaml scriptsYaml;
  final Variables variables;
  final Bindings bindings;

  @override
  String get description => 'Runs a script';

  @override
  String get name => 'run';

  @override
  List<String> get aliases => ['r'];

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final keys = args ?? argResults?.rest;

    final validateResult = await validate(keys);
    if (validateResult != null) {
      return validateResult;
    }
    assert(keys != null, 'keys should not be null');
    keys!;

    var (exitCode, commands, bail) = commandsToRun(keys);

    if (exitCode != null) {
      return exitCode;
    }
    assert(commands != null, 'commands should not be null');
    commands!;

    bail ^= argResults?['bail'] as bool? ?? false;

    if (bail) {
      getIt<SipConsole>().w('Bail is set, stopping on first error');
    }

    getIt<SipConsole>().emptyLine();

    ExitCode? failureExitCode;

    ExitCode? _bail(List<ExitCode> exitCodes, List<CommandToRun> commands) {
      getIt<SipConsole>().d('Checking for bail ($bail), bail: $exitCodes');

      if (exitCodes.exitCode == ExitCode.success) return null;
      failureExitCode ??= exitCodes.exitCode;

      if (!bail) return null;

      getIt<SipConsole>().e('Bailing...');
      getIt<SipConsole>().emptyLine();

      return exitCodes.exitCode;
    }

    var concurrentRuns = <CommandToRun>[];
    Future<ExitCode?> _runMany() async {
      if (concurrentRuns.isEmpty) return null;

      getIt<SipConsole>()
          .w('Running ${concurrentRuns.length} scripts concurrently');

      final exitCodes = await RunManyScripts(
        commands: concurrentRuns,
        bindings: bindings,
      ).run();

      exitCodes.printErrors(concurrentRuns);

      final bailExitCode = _bail(exitCodes, concurrentRuns);
      concurrentRuns.clear();

      getIt<SipConsole>().emptyLine();

      return bailExitCode;
    }

    for (final command in commands) {
      if (command.runConcurrently) {
        concurrentRuns.add(command);
        continue;
      } else if (concurrentRuns.isNotEmpty) {
        if (await _runMany() case final ExitCode exitCode) {
          return exitCode;
        }
      }

      final exitCode = await RunOneScript(
        command: command,
        bindings: bindings,
      ).run();

      exitCode.printError(command);

      getIt<SipConsole>().v('Ran script, exiting with: $exitCode');

      if (_bail([exitCode], [command]) case final ExitCode bailCode) {
        return bailCode;
      }

      getIt<SipConsole>().emptyLine();
    }

    if (await _runMany() case final ExitCode exitCode) {
      return exitCode;
    }

    getIt<SipConsole>().d('Success! Finished running scripts');

    return failureExitCode ?? ExitCode.success;
  }
}
