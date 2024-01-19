import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:sip/domain/cwd_impl.dart';
import 'package:sip/domain/pubspec_yaml_impl.dart';
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

    final scriptsToRun = <Future<int>>[];

    final resolvedCommands = variables.replace(script, scriptConfig);

    final finishers =
        getIt<SipConsole>().progress(resolvedCommands.map((e) => 'Running'));

    // lets try to change this to a stream controller instead of futures, this way we can
    // run the scripts as they finish instead of waiting for all of them to finish
    for (var i = 0; i < resolvedCommands.length; i++) {
      final finish = finishers[i];
      final command = resolvedCommands[i];

      scriptsToRun.add(
        Isolate.run(() async {
          final result = await bindings.runScript(command, showOutput: false);

          finish();

          return result;
        }),
      );
    }

    final results = await Future.wait(scriptsToRun);

    if (results.any((r) => r != ExitCode.success)) {
      await finishers.failAll();

      getIt<SipConsole>().e('One or more scripts failed');

      return ExitCode.ioError;
    }

    await finishers.all();

    return ExitCode.success;
  }
}
