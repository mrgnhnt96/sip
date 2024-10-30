import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/commands/list_command.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/cwd.dart';
import 'package:sip_cli/domain/env_config.dart';
import 'package:sip_cli/domain/optional_flags.dart';
import 'package:sip_cli/domain/script.dart';
import 'package:sip_cli/domain/script_env.dart';
import 'package:sip_cli/domain/scripts_config.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/domain/variables.dart';
import 'package:sip_cli/utils/constants.dart';
import 'package:sip_cli/utils/exit_code.dart';

mixin RunScriptHelper on Command<ExitCode> {
  ScriptsYaml get scriptsYaml;
  Variables get variables;
  CWD get cwd;

  String get directory;

  Logger get logger;

  void addFlags() {
    argParser.addFlag(
      'list',
      abbr: 'l',
      negatable: false,
      aliases: ['ls', 'h'],
      help: 'List all available scripts',
    );
  }

  FutureOr<ExitCode?> validate(List<String>? keys) async {
    if (keys == null || keys.isEmpty) {
      const warning = 'No script specified, choose from:';
      logger
        ..warn(lightYellow.wrap(warning))
        ..write('\n');

      return ListCommand(
        scriptsYaml: scriptsYaml,
        logger: logger,
      ).run();
    }

    if (keys.any((e) => e.startsWith('_'))) {
      logger.err(
        r'''
Private scripts are not intended to be invoked, only to be used as a references in other scripts.

```yaml
format:
  _: dart format .
  ui: cd packages/ui && {$format:_}
```

$ sip format ui
''',
      );
      return ExitCode.config;
    }

    return null;
  }

  OptionalFlags optionalFlags(List<String> keys) {
    final flagStartAt = keys.indexWhere((e) => e.startsWith('-'));
    final flagArgs = flagStartAt == -1 ? <String>[] : keys.sublist(flagStartAt);

    return OptionalFlags(flagArgs);
  }

  void _listOutScript(Script script) {
    logger
      ..write('\n')
      ..info(script.name)
      ..write(
        script.listOut(
          wrapCallableKey: (s) => lightGreen.wrap(s) ?? s,
          wrapMeta: (s) => lightBlue.wrap(s) ?? s,
        ),
      )
      ..write('\n');
  }

  Iterable<GetCommandsResult> getCommands(
    List<String> keys, {
    required bool listOut,
  }) sync* {
    final flagStartAt = keys.indexWhere((e) => e.startsWith('-'));
    final scriptKeys = keys.sublist(0, flagStartAt == -1 ? null : flagStartAt);

    if (scriptKeys.isEmpty) {
      logger.err('No script specified');
      yield GetCommandsResult.exit(ExitCode.config);
      return;
    }

    final content = scriptsYaml.scripts();
    if (content == null) {
      logger.err('No ${ScriptsYaml.fileName} file found');
      yield GetCommandsResult.exit(ExitCode.noInput);
      return;
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    final script = scriptConfig.find(scriptKeys);

    if (script == null) {
      logger.err('No script found for ${scriptKeys.join(' ')}');
      yield GetCommandsResult.exit(ExitCode.config);
      return;
    }

    if (listOut) {
      _listOutScript(script);

      yield GetCommandsResult.exit(ExitCode.success);
      return;
    }

    if (script.commands.isEmpty) {
      logger
        ..warn('There are no commands to run for "${scriptKeys.join(' ')}"')
        ..warn('Here are the available scripts:');

      _listOutScript(script);

      yield GetCommandsResult.exit(ExitCode.config);
      return;
    }

    final _replaced = variables.replace(
      script,
      scriptConfig,
      flags: optionalFlags(keys),
    );

    for (final replaced in _replaced) {
      yield GetCommandsResult(
        commands: replaced.commands,
        envConfig: replaced.allEnvCommands.combine(directory: directory),
        script: script,
      );
    }
  }

  Iterable<CommandToRun> _commandsToRun(GetCommandsResult getCommands) sync* {
    final GetCommandsResult(:commands, :script, :envConfig) = getCommands;
    if (commands == null || script == null) {
      return;
    }

    for (var i = 0; i < commands.length; i++) {
      var command = commands.elementAt(i);
      var runConcurrently = false;

      if (command.startsWith(Identifiers.concurrent)) {
        logger.detail(
          'Running concurrently: "${darkGray.wrap(command)}"',
        );

        runConcurrently = true;
        while (command.startsWith(Identifiers.concurrent)) {
          command = command.substring(Identifiers.concurrent.length);
        }
      }

      yield CommandToRun(
        command: command,
        label: command,
        runConcurrently: runConcurrently,
        workingDirectory: directory,
        keys: [...?script.parents, script.name],
        envConfig: envConfig,
      );
    }
  }

  CommandsToRunResult commandsToRun(
    List<String> keys, {
    required bool listOut,
  }) {
    final commands = <CommandToRun>[];

    bool bail = false;

    final allResults = getCommands(keys, listOut: listOut);
    for (final result in allResults) {
      final GetCommandsResult(:exitCode, :script, :envConfig) = result;

      if (exitCode != null || script == null) {
        return CommandsToRunResult.fail(
          exitCode,
          bail: script?.bail ?? false,
        );
      }

      bail ^= script.bail;

      assert(result.commands != null, 'commands should not be null');
      commands.addAll(_commandsToRun(result));
    }

    return CommandsToRunResult(
      commands: commands,
      bail: bail,
      combinedEnvConfig: commands.combineEnv(),
    );
  }
}

class CommandsToRunResult {
  const CommandsToRunResult({
    required Iterable<CommandToRun> this.commands,
    required this.bail,
    required this.combinedEnvConfig,
  }) : exitCode = null;

  const CommandsToRunResult.fail(this.exitCode, {required this.bail})
      : commands = null,
        combinedEnvConfig = null;

  final ExitCode? exitCode;
  final Iterable<CommandToRun>? commands;
  final EnvConfig? combinedEnvConfig;
  final bool bail;
}

class GetCommandsResult {
  GetCommandsResult({
    required Iterable<String> this.commands,
    required EnvConfig? this.envConfig,
    required Script this.script,
  }) : exitCode = null;

  GetCommandsResult.exit(
    this.exitCode,
  )   : commands = null,
        envConfig = null,
        script = null;

  final ExitCode? exitCode;
  final Iterable<String>? commands;
  final EnvConfig? envConfig;
  final Script? script;
}

extension _CombineEnvConfigCommandToRunX on Iterable<CommandToRun> {
  EnvConfig combineEnv() {
    final commands = <String>{};
    final files = <String>{};
    String? workingDirectory;

    for (final command in this) {
      final config = command.envConfig;
      if (config == null) continue;

      commands.addAll(config.commands ?? []);
      files.addAll(config.files ?? []);
      workingDirectory ??= command.workingDirectory;
    }

    return EnvConfig(
      commands: commands,
      files: files,
      workingDirectory: workingDirectory ?? '',
    );
  }
}

extension _CombineEnvConfigEnvConfigX on Iterable<EnvConfig> {
  EnvConfig? combine({required String directory}) {
    final commands = <String>{};
    final files = <String>{};

    for (final config in this) {
      commands.addAll(config.commands ?? []);
      files.addAll(config.files ?? []);
    }

    if (commands.isEmpty && files.isEmpty) return null;

    return EnvConfig(
      commands: commands,
      files: files,
      workingDirectory: directory,
    );
  }
}

extension _ScriptEnvX on ScriptEnv {
  EnvConfig? envConfig({required String directory}) {
    if (commands.isEmpty && files.isEmpty) return null;

    return EnvConfig(
      commands: {...commands},
      files: {...files},
      workingDirectory: directory,
    );
  }
}
