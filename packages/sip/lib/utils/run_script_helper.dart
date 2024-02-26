import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/commands/list_command.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

mixin RunScriptHelper on Command<ExitCode> {
  ScriptsYaml get scriptsYaml;
  Variables get variables;

  String? _directory;
  String _findDirectory() {
    final nearest = scriptsYaml.nearest();
    final directory = nearest == null
        ? getIt<FileSystem>().currentDirectory.path
        : path.dirname(nearest);

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
      getIt<SipConsole>()
        ..w(lightYellow.wrap(warning) ?? warning)
        ..emptyLine();

      return ListCommand(
        scriptsYaml: scriptsYaml,
      ).run();
    }

    if (keys.any((e) => e.startsWith('_'))) {
      getIt<SipConsole>().e(
        r'''Private scripts are not intended to be invoked, only to be used as a references in other scripts.

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
    getIt<SipConsole>()
      ..emptyLine()
      ..l(script.name)
      ..print(script.listOut(
        wrapCallableKey: (s) => lightGreen.wrap(s) ?? s,
        wrapMeta: (s) => lightBlue.wrap(s) ?? s,
      ))
      ..emptyLine();
  }

  (ExitCode?, List<String>? commands, Script?) getCommands(
    List<String> keys,
    ArgResults argResults,
  ) {
    final flagStartAt = keys.indexWhere((e) => e.startsWith('-'));
    final scriptKeys = keys.sublist(0, flagStartAt == -1 ? null : flagStartAt);

    final content = scriptsYaml.scripts();
    if (content == null) {
      getIt<SipConsole>().e('No ${ScriptsYaml.fileName} file found');
      return (ExitCode.noInput, null, null);
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    final script = scriptConfig.find(scriptKeys);

    if (script == null) {
      getIt<SipConsole>().e('No script found for ${scriptKeys.join(' ')}');
      return (ExitCode.config, null, null);
    }

    if (argResults['list'] ?? false) {
      _listOutScript(script);

      return (ExitCode.success, null, null);
    }

    if (script.commands.isEmpty) {
      getIt<SipConsole>()
        ..w('There are no commands to run for "${scriptKeys.join(' ')}"')
        ..w('Here are the available scripts:');

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
      Script script, List<String> commands) sync* {
    for (var i = 0; i < commands.length; i++) {
      var command = commands[i];

      yield CommandToRun(
        command: command,
        label: command,
        runConcurrently: false,
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
