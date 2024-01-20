import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip/domain/cwd_impl.dart';
import 'package:sip/domain/pubspec_yaml_impl.dart';
import 'package:sip/domain/run_many.dart';
import 'package:sip/domain/scripts_yaml_impl.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class ScriptRunManyCommand extends Command<ExitCode> {
  ScriptRunManyCommand({
    this.scriptsYaml = const ScriptsYamlImpl(),
    this.variables = const Variables(
      scriptsYaml: const ScriptsYamlImpl(),
      pubspecYaml: const PubspecYamlImpl(),
      cwd: const CWDImpl(),
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
      // TODO: print list of available scripts
      getIt<SipConsole>().d('TODO: print list of available scripts');
      return ExitCode.usage;
    }

    if (content == null) {
      getIt<SipConsole>().e('No script found for ${keys.join(' ')}');
      return ExitCode.osFile;
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    final script = scriptConfig.find(keys);

    if (script == null) {
      getIt<SipConsole>().e('No script found for ${keys.join(' ')}');
      return ExitCode.ioError;
    }

    final resolvedCommands = variables.replace(script, scriptConfig);

    final nearest = scriptsYaml.nearest();
    final directory = nearest == null
        ? getIt<FileSystem>().currentDirectory.path
        : path.dirname(nearest);

    final runMany = RunMany(
      commands: resolvedCommands
          .map((command) => CommandToRun(
                command: command,
                label: 'Running',
                directory: directory,
              ))
          .toList(),
      bindings: bindings,
    );

    return runMany.run();
  }
}
