import 'dart:async';

import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:args/command_runner.dart';
import 'package:sip_cli/commands/list_command.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/domain/optional_flags.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:sip_script_runner/utils/constants.dart';

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

  (ExitCode?, List<String>? commands) getCommands(List<String> keys) {
    final flagStartAt = keys.indexWhere((e) => e.startsWith('-'));
    final scriptKeys = keys.sublist(0, flagStartAt == -1 ? null : flagStartAt);

    final content = scriptsYaml.scripts();
    if (content == null) {
      getIt<SipConsole>().e('No ${ScriptsYaml.fileName} file found');
      return (ExitCode.noInput, null);
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    final script = scriptConfig.find(scriptKeys);

    if (script == null) {
      getIt<SipConsole>().e('No script found for ${scriptKeys.join(' ')}');
      return (ExitCode.config, null);
    }

    if (script.commands.isEmpty) {
      getIt<SipConsole>()
        ..w('There are no commands to run for "${scriptKeys.join(' ')}"')
        ..w('Here are the available scripts:');

      _listOutScript(script);

      return (ExitCode.config, null);
    }

    if (argResults?.wasParsed('list') ?? false) {
      _listOutScript(script);

      return (ExitCode.success, null);
    }

    final resolvedCommands = variables.replace(
      script,
      scriptConfig,
      flags: optionalFlags(keys),
    );

    return (null, resolvedCommands);
  }

  Iterable<CommandToRun> _commandsToRun(List<String> commands) sync* {
    for (var command in commands) {
      var runConcurrently = false;

      if (command.startsWith(Identifiers.concurrent)) {
        runConcurrently = true;
        command = command.substring(Identifiers.concurrent.length);
      }

      yield CommandToRun(
        command: command,
        label: command,
        runConcurrently: runConcurrently,
        workingDirectory: directory,
      );
    }
  }

  (ExitCode?, Iterable<CommandToRun>?) commandsToRun(List<String> keys) {
    final (exitCode, commands) = getCommands(keys);

    if (exitCode != null) {
      return (exitCode, null);
    }

    assert(commands != null, 'commands should not be null');
    commands!;

    return (null, _commandsToRun(commands));
  }
}
