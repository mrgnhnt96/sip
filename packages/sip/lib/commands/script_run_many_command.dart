import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:sip/domain/pubspec_yaml.dart';
import 'package:sip/domain/scripts_yaml.dart';
import 'package:sip/domain/variables.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class ScriptRunManyCommand extends Command<ExitCode> {
  ScriptRunManyCommand({
    this.scriptsYaml = const ScriptsYaml(),
    this.variables = const Variables(
      scriptsYaml: const ScriptsYaml(),
      pubspecYaml: const PubspecYaml(),
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

    final scriptsToRun = <Future<int>>[];

    final resolvedCommands = variables.replace(script, scriptConfig);

    // lets try to change this to a stream controller instead of futures, this way we can
    // run the scripts as they finish instead of waiting for all of them to finish
    for (final command in resolvedCommands) {
      scriptsToRun.add(
        Isolate.run(() async {
          final result = await bindings.runScript(command, showOutput: false);

          print('Finished $command with $result');

          return result;
        }),
      );
    }

    final results = await Future.wait(scriptsToRun);

    if (results.any((r) => r != ExitCode.success)) {
      return ExitCode.ioError;
    }

    return ExitCode.success;
  }
}
