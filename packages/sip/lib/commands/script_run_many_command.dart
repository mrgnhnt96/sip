import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:sip/domain/scripts_yaml.dart';
import 'package:sip/setup/dependency_injection.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class ScriptRunManyCommand extends Command<ExitCode> {
  ScriptRunManyCommand({
    this.scriptsYaml = const ScriptsYaml(),
    this.bindings = const BindingsImpl(),
  });

  final ScriptsYaml scriptsYaml;
  final Bindings bindings;

  @override
  String get description => 'Runs a script';

  @override
  String get name => 'run-many';

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

    final scriptsToRun = <Future<int>>[];

    for (final command in script.commands) {
      scriptsToRun.add(
        Isolate.run(() async {
          final result = await bindings.runScript(command, showOutput: false);

          print('Finished $command with $result');

          return result;
        }),
      );
    }

    await Future.delayed(const Duration(seconds: 1));

    final results = await Future.wait(scriptsToRun);

    if (results.any((r) => r != ExitCode.success)) {
      return ExitCode.ioError;
    }

    return ExitCode.success;
  }
}
