import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/list_command.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/cwd.dart';
import 'package:sip_cli/domain/env_config.dart';
import 'package:sip_cli/domain/optional_flags.dart';
import 'package:sip_cli/domain/script.dart';
import 'package:sip_cli/domain/scripts_config.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/domain/variables.dart';
import 'package:sip_cli/utils/constants.dart';
import 'package:sip_cli/utils/exit_code.dart';

mixin RunScriptHelper on Command<ExitCode> {
  ScriptsYaml get scriptsYaml;
  Variables get variables;
  CWD get cwd;

  Logger get logger;

  String? _directory;
  String _findDirectory() {
    final nearest = scriptsYaml.nearest();
    final directory = nearest == null ? cwd.path : path.dirname(nearest);

    return directory;
  }

  String get directory => _directory ??= _findDirectory();

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

  GetCommandsResult getCommands(
    List<String> keys, {
    required bool listOut,
  }) {
    final flagStartAt = keys.indexWhere((e) => e.startsWith('-'));
    final scriptKeys = keys.sublist(0, flagStartAt == -1 ? null : flagStartAt);

    if (scriptKeys.isEmpty) {
      logger.err('No script specified');
      return GetCommandsResult.exit(ExitCode.config);
    }

    final content = scriptsYaml.scripts();
    if (content == null) {
      logger.err('No ${ScriptsYaml.fileName} file found');
      return GetCommandsResult.exit(ExitCode.noInput);
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    final script = scriptConfig.find(scriptKeys);

    if (script == null) {
      logger.err('No script found for ${scriptKeys.join(' ')}');
      return GetCommandsResult.exit(ExitCode.config);
    }

    if (listOut) {
      _listOutScript(script);

      return GetCommandsResult.exit(ExitCode.success);
    }

    if (script.commands.isEmpty) {
      logger
        ..warn('There are no commands to run for "${scriptKeys.join(' ')}"')
        ..warn('Here are the available scripts:');

      _listOutScript(script);

      return GetCommandsResult.exit(ExitCode.config);
    }

    final replaced = variables.replace(
      script,
      scriptConfig,
      flags: optionalFlags(keys),
    );

    final envCommand = EnvConfig(
      commands: {
        if (replaced.envCommands case final commands)
          ...commands.expand((e) => e.commands ?? []),
      },
      files: {
        if (replaced.envCommands case final commands)
          ...commands.expand((e) => e.files ?? []),
      },
    );

    return GetCommandsResult(
      commands: replaced.commands,
      envConfig: envCommand,
      script: script,
    );
  }

  Iterable<CommandToRun> _commandsToRun(GetCommandsResult getCommands) sync* {
    final GetCommandsResult(:commands, :envConfig, :script) = getCommands;
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
        envFile: envConfig ?? EnvConfig.empty(),
        runConcurrently: runConcurrently,
        workingDirectory: directory,
        keys: [...?script.parents, script.name],
      );
    }
  }

  CommandsToRunResult commandsToRun(
    List<String> keys, {
    required bool listOut,
  }) {
    final result = getCommands(keys, listOut: listOut);
    final GetCommandsResult(:exitCode, :script) = result;

    if (exitCode != null || script == null) {
      return CommandsToRunResult(
        exitCode: result.exitCode,
        commands: null,
        bail: result.script?.bail ?? false,
      );
    }

    assert(result.commands != null, 'commands should not be null');

    return CommandsToRunResult(
      exitCode: null,
      commands: _commandsToRun(result),
      bail: script.bail,
    );
  }
}

class CommandsToRunResult {
  const CommandsToRunResult({
    required this.exitCode,
    required this.commands,
    required this.bail,
  });

  final ExitCode? exitCode;
  final Iterable<CommandToRun>? commands;
  final bool bail;
}

class GetCommandsResult {
  GetCommandsResult({
    required Iterable<String> this.commands,
    required EnvConfig this.envConfig,
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
