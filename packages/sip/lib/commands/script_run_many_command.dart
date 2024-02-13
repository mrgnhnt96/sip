import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:sip_cli/domain/any_arg_parser.dart';
import 'package:sip_cli/domain/cwd_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/scripts_yaml_impl.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';
import 'package:sip_cli/utils/run_script_helper.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

/// The command to run many scripts concurrently
class ScriptRunManyCommand extends Command<ExitCode> with RunScriptHelper {
  ScriptRunManyCommand({
    this.scriptsYaml = const ScriptsYamlImpl(),
    this.variables = const Variables(
      scriptsYaml: ScriptsYamlImpl(),
      pubspecYaml: PubspecYamlImpl(),
      cwd: CWDImpl(),
    ),
    this.bindings = const BindingsImpl(),
  }) : argParser = AnyArgParser() {
    addFlags();
  }

  @override
  final ArgParser argParser;

  final ScriptsYaml scriptsYaml;
  final Variables variables;
  final Bindings bindings;

  @override
  String get description => 'Runs many scripts concurrently';

  @override
  String get name => 'run-many';

  @override
  List<String> get aliases => ['r-m', 'run-m'];

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final argResults = argParser.parse(args ?? this.argResults?.rest ?? []);
    final keys = args ?? argResults.rest;

    final validateResult = await validate(keys);
    if (validateResult != null) {
      return validateResult;
    }

    final (exitCode, commands, _) = commandsToRun(keys, argResults);

    if (exitCode != null) {
      return exitCode;
    }
    assert(commands != null, 'commands should not be null');
    commands!;

    getIt<SipConsole>().w('Running ${commands.length} scripts concurrently');

    final exitCodes = await RunManyScripts(
      commands: commands,
      bindings: bindings,
    ).run();

    exitCodes.printErrors(commands);

    return exitCodes.exitCode;
  }
}
