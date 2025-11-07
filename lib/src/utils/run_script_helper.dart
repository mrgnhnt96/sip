import 'dart:async';

import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/src/commands/list_command.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/deps/variables.dart';
import 'package:sip_cli/src/domain/command_to_run.dart';
import 'package:sip_cli/src/domain/env_config.dart';
import 'package:sip_cli/src/domain/optional_flags.dart';
import 'package:sip_cli/src/domain/resolve_script.dart';
import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/utils/constants.dart';
import 'package:sip_cli/src/utils/exit_code.dart';

mixin RunScriptHelper {
  String get directory;

  Future<ExitCode?> validate(List<String>? keys) async {
    if (keys == null || keys.isEmpty) {
      const warning = 'No script specified, choose from:';
      logger
        ..warn(lightYellow.wrap(warning))
        ..write('\n');

      return await const ListCommand().run();
    }

    if (keys.any((e) => e.startsWith('_'))) {
      logger.err(r'''
Private scripts are not intended to be invoked, only to be used as a references in other scripts.

```yaml
format:
  _: dart format .
  ui: cd packages/ui && {$format:_}
```

$ sip format ui
''');
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

  List<GetCommandsResult> getCommands(
    List<String> keys, {
    required bool listOut,
  }) {
    Iterable<GetCommandsResult> create() sync* {
      final flagStartAt = keys.indexWhere((e) => e.startsWith('-'));
      final scriptKeys = keys.sublist(
        0,
        flagStartAt == -1 ? null : flagStartAt,
      );

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
        yield GetCommandsResult(resolveScript: resolved, script: script);
      }
    }

    return create().toList();
  }

  List<CommandToRun> _commandsToRun(GetCommandsResult getCommands) {
    Iterable<CommandToRun> create() sync* {
      final GetCommandsResult(:resolveScript, :script) = getCommands;
      if (resolveScript == null || script == null) {
        return;
      }

      final ResolveScript(:resolvedScripts, :envConfig) = resolveScript;

      for (final (index, resolved) in resolvedScripts.indexed) {
        var runConcurrently = false;

        var command = switch (resolved.command) {
          final String command => command,
          null => throw Exception('Command is null'),
        };

        if (command.contains(Identifiers.concurrent)) {
          logger.detail('Running concurrently: "${cyan.wrap('$index')}"');

          runConcurrently = true;
          command = command.replaceAll(Identifiers.concurrent, '');
        }

        yield CommandToRun(
          command: command.trim(),
          label: command.trim(),
          runConcurrently: runConcurrently,
          workingDirectory: directory,
          keys: resolved.script.keys,
          envConfig: resolved.envConfig,
          needsRunBeforeNext: resolved.needsRunBeforeNext,
        );
      }
    }

    return create().toList();
  }

  List<CommandsToRunResult> commandsToRun(
    List<String> keys, {
    required bool listOut,
  }) {
    Iterable<CommandsToRunResult> create() sync* {
      var bail = false;

      final allResults = getCommands(keys, listOut: listOut);
      for (final result in allResults) {
        final GetCommandsResult(:exitCode, :script, :resolveScript) = result;

        if (exitCode != null || script == null) {
          yield CommandsToRunResult.fail(exitCode, bail: script?.bail ?? bail);

          return;
        }

        bail ^= script.bail;

        assert(resolveScript != null, 'commands should not be null');
        yield CommandsToRunResult(
          commands: _commandsToRun(result).toList(),
          bail: bail,
          combinedEnvConfig: resolveScript?.envConfig,
        );
      }
    }

    return create().toList();
  }
}

class CommandsToRunResult {
  const CommandsToRunResult({
    required List<CommandToRun> this.commands,
    required this.bail,
    required this.combinedEnvConfig,
  }) : exitCode = null;

  const CommandsToRunResult.fail(this.exitCode, {required this.bail})
    : commands = null,
      combinedEnvConfig = null;

  final ExitCode? exitCode;
  final List<CommandToRun>? commands;
  final EnvConfig? combinedEnvConfig;
  final bool bail;
}

class GetCommandsResult {
  GetCommandsResult({
    required ResolveScript this.resolveScript,
    required Script this.script,
  }) : exitCode = null;

  GetCommandsResult.exit(this.exitCode) : resolveScript = null, script = null;

  final ExitCode? exitCode;
  final Script? script;
  final ResolveScript? resolveScript;
}
