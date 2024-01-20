import 'package:args/command_runner.dart';
import 'package:sip/domain/cwd_impl.dart';
import 'package:sip/domain/pubspec_yaml_impl.dart';
import 'package:sip/domain/scripts_yaml_impl.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class ScriptRunCommand extends Command<ExitCode> {
  ScriptRunCommand({
    this.scriptsYaml = const ScriptsYamlImpl(),
    this.variables = const Variables(
      pubspecYaml: const PubspecYamlImpl(),
      scriptsYaml: const ScriptsYamlImpl(),
      cwd: const CWDImpl(),
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

  final ScriptsYamlImpl scriptsYaml;
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
      // TODO: print list of available scripts
      getIt<SipConsole>().d('TODO: print list of available scripts');
      return ExitCode.usage;
    }

    if (content == null) {
      getIt<SipConsole>().e('No ${ScriptsYaml.fileName} file found');
      return ExitCode.osFile;
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    final script = scriptConfig.find(keys);

    if (script == null) {
      getIt<SipConsole>().e('No script found for ${keys.join(' ')}');
      return ExitCode.ioError;
    }

    final failFast = argResults?.wasParsed('fail-fast') ?? false;

    final resolvedCommands = variables.replace(script, scriptConfig);

    getIt<SipConsole>().emptyLine();

    for (final command in resolvedCommands) {
      getIt<SipConsole>().l('${darkGray.wrap(command)}');
      final code = await bindings.runScript(command);

      if (code != 0 && failFast) {
        getIt<SipConsole>().e('Script failed with exit code $code');
        return ExitCode.software;
      }

      getIt<SipConsole>().emptyLine();
    }

    return ExitCode.success;
  }
}
