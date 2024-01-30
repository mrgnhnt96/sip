import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip/commands/list_command.dart';
import 'package:sip/domain/command_to_run.dart';
import 'package:sip/domain/cwd_impl.dart';
import 'package:sip/domain/pubspec_yaml_impl.dart';
import 'package:sip/domain/run_many_scripts.dart';
import 'package:sip/domain/scripts_yaml_impl.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip/utils/exit_code_extensions.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

/// The command to run many scripts concurrently
class ScriptRunManyCommand extends Command<ExitCode> {
  ScriptRunManyCommand({
    this.scriptsYaml = const ScriptsYamlImpl(),
    this.variables = const Variables(
      scriptsYaml: ScriptsYamlImpl(),
      pubspecYaml: PubspecYamlImpl(),
      cwd: CWDImpl(),
    ),
    this.bindings = const BindingsImpl(),
  });

  final ScriptsYaml scriptsYaml;
  final Variables variables;
  final Bindings bindings;

  @override
  String get description => 'Runs many scripts concurrently';

  @override
  String get name => 'run-many';

  @override
  Future<ExitCode> run() async {
    final content = scriptsYaml.parse();

    final keys = argResults?.rest;

    if (keys == null || keys.isEmpty) {
      const warning = 'No script specified, choose from:';
      getIt<SipConsole>()
        ..w(lightYellow.wrap(warning) ?? warning)
        ..emptyLine();

      return ListCommand(
        scriptsYaml: scriptsYaml,
      ).run();
    }

    if (content == null) {
      getIt<SipConsole>().e('No script found for ${keys.join(' ')}');
      return ExitCode.noInput;
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    final script = scriptConfig.find(keys);

    if (script == null) {
      getIt<SipConsole>().e('No script found for ${keys.join(' ')}');
      return ExitCode.config;
    }

    final resolvedCommands = variables.replace(script, scriptConfig);

    final nearest = scriptsYaml.nearest();
    final directory = nearest == null
        ? getIt<FileSystem>().currentDirectory.path
        : path.dirname(nearest);

    getIt<SipConsole>()
        .w('Running ${resolvedCommands.length} scripts concurrently');

    final commands = resolvedCommands
        .map((command) => CommandToRun(
              command: command,
              label: command,
              workingDirectory: directory,
            ))
        .toList();

    final runMany = RunManyScripts(
      commands: commands,
      bindings: bindings,
    );

    final exitCodes = await runMany.run();

    exitCodes.printErrors(commands);

    return exitCodes.exitCode;
  }
}
