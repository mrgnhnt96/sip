import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:sip/domain/scripts_yaml.dart';
import 'package:sip/setup/dependency_injection.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class ScriptRunCommand extends Command<ExitCode> {
  ScriptRunCommand({
    this.scriptsYaml = const ScriptsYaml(),
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
  final Bindings bindings;

  @override
  String get description => 'Runs a script';

  @override
  String get name => 'run';

  @override
  Future<ExitCode> run() async {
    final content = scriptsYaml.parse();

    final keys = argResults?.rest;

    if (keys == null || keys.isEmpty) {
      getIt<Logger>().err('Need to run the list option first');
      return ExitCode.usage;
    }

    if (content == null) {
      getIt<Logger>().err('No ${ScriptsYaml.fileName} file found');
      return ExitCode.osFile;
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    final script = scriptConfig.find(keys);

    if (script == null) {
      getIt<Logger>().err('No script found for ${keys.join(' ')}');
      return ExitCode.ioError;
    }

    final failFast = argResults?.wasParsed('fail-fast') ?? false;

    for (final command in script.commands) {
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
