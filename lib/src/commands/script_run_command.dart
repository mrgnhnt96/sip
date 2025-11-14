// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/script_runner.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/resolved_script.dart';
import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:sip_cli/src/utils/run_script_helper.dart';
import 'package:sip_cli/src/utils/working_directory.dart';

const _usage = '''
Usage: sip run <script>

Runs a script

Options:
  --list, --ls, -l        List all available scripts
  --help                  Print usage information
  --print                 Print the commands that would be run without executing them
  --bail                  Stop on first error
  --never-exit, -n        !!USE WITH CAUTION!!! After the script is done,
                          the command will restart after a 1 second delay.
                          This is useful for long running scripts that should always be running.
  --no-concurrent         Turns off all concurrency, even if set in the scripts.yaml (using `(+)` symbol)
''';

/// The command to run a script
class ScriptRunCommand with RunScriptHelper, WorkingDirectory {
  const ScriptRunCommand();

  Future<ExitCode> run(List<String> keys) async {
    final help = args.get<bool>('help', defaultValue: false);
    if (help && keys.isEmpty) {
      logger.write(_usage);
      return ExitCode.success;
    }

    final neverQuit = args.get<bool>('never-exit', defaultValue: false);
    final listOut = args.get<bool>(
      'list',
      abbr: 'l',
      aliases: ['ls', 'h'],
      defaultValue: false,
    );
    final printOnly = args.get<bool>('print', defaultValue: false);

    final disableConcurrency =
        args.getOrNull<bool>('concurrent', aliases: ['parallel']) == false;

    if (disableConcurrency) {
      logger.warn('Disabling all concurrent runs');
    }

    if (await validate(keys) case final ExitCode exitCode) {
      return exitCode;
    }

    final config = ScriptsConfig.load();
    final userArgs = Args.parse(keys);

    final script = config.find(userArgs.path);
    if (script == null) {
      logger.err('No script found for ${keys.join(' ')}');
      return ExitCode.config;
    }

    if (listOut || help) {
      final output = script
          .listOut(
            wrapCallableKey: (s) => lightGreen.wrap(s) ?? s,
            wrapNonCallableKey: (s) => cyan.wrap(s) ?? s,
            wrapMeta: (s) => lightBlue.wrap(s) ?? s,
          )
          .trim();

      if (output.isEmpty) {
        final name = green.wrap(script.keys.join(' '));
        logger.info(
          darkGray.wrap('No commands, aliases, nor description for $name'),
        );
      } else {
        logger.write('\n${script.keys.join(' ')}\n');
        logger.write('$output\n');
      }

      return ExitCode.success;
    }

    final (resolved, exitCode) = script.resolve(flags: userArgs);

    if (exitCode != null) {
      return exitCode;
    }

    if (resolved == null) {
      logger.err('No resolved script found for ${userArgs.path.join(' ')}');
      return ExitCode.config;
    }

    if (printOnly) {
      for (final command in resolved.commands) {
        switch (command) {
          case ConcurrentBreak():
            continue;
          case final ScriptToRun script:
            logger
              ..write(script.exe)
              ..write('\n')
              ..write(cyan.wrap('---' * 8))
              ..write('\n')
              ..write('\n');
        }
      }

      return ExitCode.success;
    }

    final bail = resolved.bail ^ args.get<bool>('bail', defaultValue: false);

    Future<ExitCode> runCommands() => _runCommands(
      script: resolved,
      bail: bail,
      disableConcurrency: disableConcurrency,
      group: false,
    );

    if (neverQuit) {
      await runForever(runCommands);
    }

    return runCommands();
  }

  Future<void> runForever(Future<void> Function() runCommands) async {
    logger
      ..write('\n')
      ..warn('Never exit is set, restarting after each run.')
      ..warn('To exit, press Ctrl+C or close the terminal.')
      ..write('\n');

    await Future<void>.delayed(const Duration(seconds: 3));

    while (true) {
      await runCommands();

      logger
        ..warn('Restarting in 1 second')
        ..write('\n');

      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Future<ExitCode?> _runEnvCommands(ResolvedScript script) async {
    final commands = script.envConfig?.commands;
    if (commands case [] || null) return null;

    logger.detail('Running env commands');

    final (envScript, exitCode) = Script(
      name: 'env',
      commands: commands,
    ).resolve();
    if (exitCode != null) {
      logger.err('Failed to resolve env script');
      return exitCode;
    }

    if (envScript == null) {
      return null;
    }

    final result = await scriptRunner.run(envScript.commands, bail: true);

    if (result.exitCodeReason != ExitCode.success) {
      logger.err('Failed to run env commands');
      return result.exitCodeReason;
    }

    return null;
  }

  Future<ExitCode> _runCommands({
    required ResolvedScript script,
    required bool bail,
    required bool group,
    required bool disableConcurrency,
  }) async {
    if (bail) {
      logger.warn('Bail is set, stopping on first error');
    }

    final envResult = await _runEnvCommands(script);
    if (envResult != null) {
      return envResult;
    }

    final result = await scriptRunner.run(
      script.commands,
      disableConcurrency: disableConcurrency,
      bail: bail,
      onMessage: (_, message) {
        logger.write(message.message);
        return null;
      },
    );

    if (result.exitCodeReason != ExitCode.success) {
      logger.err('Failed to run commands');
      return result.exitCodeReason;
    }

    return ExitCode.success;
  }
}
