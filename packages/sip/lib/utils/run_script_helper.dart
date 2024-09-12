import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/list_command.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/cwd.dart';
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

  (ExitCode?, List<String>? commands, Script?) getCommands(
    List<String> keys,
    ArgResults argResults,
  ) {
    final flagStartAt = keys.indexWhere((e) => e.startsWith('-'));
    final scriptKeys = keys.sublist(0, flagStartAt == -1 ? null : flagStartAt);

    if (scriptKeys.isEmpty) {
      logger.err('No script specified');
      return (ExitCode.config, null, null);
    }

    final content = scriptsYaml.scripts();
    if (content == null) {
      logger.err('No ${ScriptsYaml.fileName} file found');
      return (ExitCode.noInput, null, null);
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    final script = scriptConfig.find(scriptKeys);

    if (script == null) {
      logger.err('No script found for ${scriptKeys.join(' ')}');
      return (ExitCode.config, null, null);
    }

    if (argResults['list'] as bool? ?? false) {
      _listOutScript(script);

      return (ExitCode.success, null, null);
    }

    if (script.commands.isEmpty) {
      logger
        ..warn('There are no commands to run for "${scriptKeys.join(' ')}"')
        ..warn('Here are the available scripts:');

      _listOutScript(script);

      return (ExitCode.config, null, null);
    }

    final resolvedCommands = variables.replace(
      script,
      scriptConfig,
      flags: optionalFlags(keys),
    );

    return (null, resolvedCommands, script);
  }

  Iterable<CommandToRun> _commandsToRun(
    Script script,
    List<String> commands,
  ) sync* {
    for (var i = 0; i < commands.length; i++) {
      var command = commands[i];
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
        envFile: script.env?.files ?? [],
        runConcurrently: runConcurrently,
        workingDirectory: directory,
        keys: [...?script.parents, script.name],
      );
    }
  }

  (ExitCode?, Iterable<CommandToRun>?, bool) commandsToRun(
    List<String> keys,
    ArgResults argResults,
  ) {
    final (exitCode, commands, script) = getCommands(keys, argResults);

    if (exitCode != null || script == null) {
      return (exitCode, null, script?.bail ?? false);
    }

    assert(commands != null, 'commands should not be null');
    commands!;

    return (null, _commandsToRun(script, commands), script.bail);
  }
}
