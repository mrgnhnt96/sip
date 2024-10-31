import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
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

    final resolvedScripts = variables.replace(
      script,
      scriptConfig,
      flags: optionalFlags(keys),
    );

    for (final resolved in resolvedScripts) {
      yield GetCommandsResult(
        resolveScript: resolved,
        script: script,
      );
    }
  }

  Iterable<CommandToRun> _commandsToRun(GetCommandsResult getCommands) sync* {
    final GetCommandsResult(:resolveScript, :script) = getCommands;
    if (resolveScript == null || script == null) {
      return;
    }

    final ResolveScript(:resolvedScripts, :envConfig) = resolveScript;

    for (var i = 0; i < resolvedScripts.length; i++) {
      final resolved = resolvedScripts.elementAt(i);
      var runConcurrently = false;

      var command = switch (resolved.command) {
        final String command => command,
        null => throw Exception('Command is null'),
      };

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
        command: command.trim(),
        label: command.trim(),
        runConcurrently: runConcurrently,
        workingDirectory: directory,
        keys: resolved.script.keys,
        envConfig: resolved.envConfig,
      );
    }
  }

  Iterable<CommandsToRunResult> commandsToRun(
    List<String> keys, {
    required bool listOut,
  }) sync* {
    var bail = false;

    final allResults = getCommands(keys, listOut: listOut);
    for (final result in allResults) {
      final GetCommandsResult(:exitCode, :script, :resolveScript) = result;

      if (exitCode != null || script == null) {
        yield CommandsToRunResult.fail(
          exitCode,
          bail: script?.bail ?? bail,
        );

        return;
      }

      bail ^= script.bail;

      assert(resolveScript != null, 'commands should not be null');
      yield CommandsToRunResult(
        commands: _commandsToRun(result),
        bail: bail,
        combinedEnvConfig: resolveScript?.envConfig,
      );
    }
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
    required ResolveScript this.resolveScript,
    required Script this.script,
  }) : exitCode = null;

  GetCommandsResult.exit(
    this.exitCode,
  )   : resolveScript = null,
        script = null;

  final ExitCode? exitCode;
  final Script? script;
  final ResolveScript? resolveScript;
}
