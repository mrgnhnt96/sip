import 'package:args/command_runner.dart';
import 'package:sip/domain/pubspec_yaml.dart';
import 'package:sip/domain/scripts_yaml.dart';
import 'package:sip/domain/variables.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class ScriptRunCommand extends Command<ExitCode> {
  ScriptRunCommand({
    this.scriptsYaml = const ScriptsYaml(),
    this.variables = const Variables(
      pubspecYaml: const PubspecYaml(),
      scriptsYaml: const ScriptsYaml(),
    ),
    this.bindings = const BindingsImpl(),
  }) {
    argParser.addFlag(
      'list',
      abbr: 'l',
      negatable: false,
      help: 'List all available scripts',
    );

    argParser.addFlag(
      'fail-fast',
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
  Future<ExitCode> run([List<String>? args]) async {
    final content = scriptsYaml.parse();

    final keys = args ?? argResults?.rest;

    if (keys == null || keys.isEmpty) {
      print('Need to run the list option first');
      return ExitCode.usage;
    }

    if (content == null) {
      print('No ${ScriptsYaml.fileName} file found');
      return ExitCode.osFile;
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    final script = scriptConfig.find(keys);

    if (script == null) {
      print('No script found for ${keys.join(' ')}');
      return ExitCode.ioError;
    }

    final failFast = argResults?.wasParsed('fail-fast') ?? false;

    final resolvedCommands = variables.replace(script, scriptConfig);

    for (final command in resolvedCommands) {
      final code = await bindings.runScript(command);
      print('finished with $code');

      // ctrl + c
      if (code == 69) {
        // return ExitCode.software;
      }

      if (code != 0 && failFast) {
        return ExitCode.software;
      }
    }

    return ExitCode.success;
  }
}