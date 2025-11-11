import 'dart:async';

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/commands/list_command.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/resolved_script.dart';
import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';

mixin RunScriptHelper {
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

  (ResolvedScript?, ExitCode?) getCommands(
    List<String> keys, {
    required bool listOut,
  }) {
    final args = Args.parse(keys);

    if (args.path.isEmpty) {
      logger.err('No script specified');
      return (null, ExitCode.config);
    }

    final scriptConfig = ScriptsConfig.load();

    final script = scriptConfig.find(args.path);

    if (script == null) {
      logger.err('No script found for ${args.path.join(' ')}');
      return (null, ExitCode.config);
    }

    if (listOut) {
      _listOutScript(script);

      return (null, ExitCode.success);
    }

    if (script.commands.isEmpty) {
      logger
        ..warn('There are no commands to run for "${args.path.join(' ')}"')
        ..warn('Here are the available scripts:');

      _listOutScript(script);

      return (null, ExitCode.config);
    }

    final (resolved, exitCode) = script.resolve(flags: args);

    if (exitCode case final exitCode?) {
      return (null, exitCode);
    }

    return (resolved, null);
  }
}
