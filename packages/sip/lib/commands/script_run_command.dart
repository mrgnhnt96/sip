import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip/commands/list_command.dart';
import 'package:sip/domain/command_to_run.dart';
import 'package:sip/domain/cwd_impl.dart';
import 'package:sip/domain/pubspec_yaml_impl.dart';
import 'package:sip/domain/run_one_script.dart';
import 'package:sip/domain/scripts_yaml_impl.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip/utils/exit_code_extensions.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/domain/optional_flags.dart';
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
      aliases: ['ls', 'h'],
      help: 'List all available scripts',
    );

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
    final restOfArgs = args ?? argResults?.rest;

    if (restOfArgs == null || restOfArgs.isEmpty) {
      const warning = 'No script specified, choose from:';
      getIt<SipConsole>()
        ..w(lightYellow.wrap(warning) ?? warning)
        ..emptyLine();

      return ListCommand(
        scriptsYaml: scriptsYaml,
      ).run();
    }

    final flagStartAt = restOfArgs.indexWhere((e) => e.startsWith('-'));
    final scriptKeys =
        restOfArgs.sublist(0, flagStartAt == -1 ? null : flagStartAt);
    final flagArgs =
        flagStartAt == -1 ? <String>[] : restOfArgs.sublist(flagStartAt);

    final optionalFlags = OptionalFlags(flagArgs);

    final content = scriptsYaml.parse();
    if (content == null) {
      getIt<SipConsole>().e('No ${ScriptsYaml.fileName} file found');
      return ExitCode.noInput;
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    final script = scriptConfig.find(scriptKeys);

    if (script == null) {
      getIt<SipConsole>().e('No script found for ${scriptKeys.join(' ')}');
      return ExitCode.config;
    }

    if (argResults?.wasParsed('list') ?? false) {
      getIt<SipConsole>()
        ..emptyLine()
        ..l(script.listOut(
          wrapKey: (s) => lightGreen.wrap(s) ?? s,
          wrapMeta: (s) => lightBlue.wrap(s) ?? s,
        ))
        ..emptyLine();

      return ExitCode.success;
    }

    final bail = argResults?.wasParsed('bail') ?? false;

    final resolvedCommands = variables.replace(
      script,
      scriptConfig,
      flags: optionalFlags,
    );

    getIt<SipConsole>().emptyLine();

    final nearest = scriptsYaml.nearest();
    final directory = nearest == null
        ? getIt<FileSystem>().currentDirectory.path
        : path.dirname(nearest);

    for (final command in resolvedCommands) {
      final commandToRun = CommandToRun(
        command: command,
        label: command,
        workingDirectory: directory,
      );

      final result = await RunOneScript(
        command: commandToRun,
        bindings: bindings,
      ).run();

      getIt<SipConsole>().emptyLine();

      if (result != ExitCode.success && bail) {
        result.printError(commandToRun);

        return result;
      }
    }

    return ExitCode.success;
  }
}
