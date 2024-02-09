import 'package:args/command_runner.dart';
import 'package:sip_cli/domain/cwd_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
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

    final (exitCode, commands) = commandsToRun(keys);

    if (exitCode != null) {
      return exitCode;
    }
    assert(commands != null, 'commands should not be null');
    commands!;

    final bail = argResults?.wasParsed('bail') ?? false;

    getIt<SipConsole>().emptyLine();
    for (final command in commands) {
      final result = await RunOneScript(
        command: command,
        bindings: bindings,
      ).run();

      getIt<SipConsole>().emptyLine();

      if (result != ExitCode.success && bail) {
        getIt<SipConsole>().e('Bailing...');
        getIt<SipConsole>().emptyLine();

        result.printError(command);

        return result;
      }
    }

    return ExitCode.success;
  }
}
