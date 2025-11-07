// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/run_many_scripts.dart';
import 'package:sip_cli/src/deps/run_one_script.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/command_to_run.dart';
import 'package:sip_cli/src/domain/env_config.dart';
import 'package:sip_cli/src/utils/exit_code.dart';
import 'package:sip_cli/src/utils/exit_code_extensions.dart';
import 'package:sip_cli/src/utils/run_script_helper.dart';
import 'package:sip_cli/src/utils/stopwatch_extensions.dart';
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
  --[no-]concurrent, -c   Runs all scripts concurrently. --no-concurrent will turn
                          off concurrency even if set in the scripts.yaml
''';

/// The command to run a script
class ScriptRunCommand with RunScriptHelper, WorkingDirectory {
  const ScriptRunCommand();

  Future<ExitCode> run(List<String> keys) async {
    if (args.get<bool>('help', defaultValue: false)) {
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

    final concurrent = args.getOrNull<bool>(
      'concurrent',
      abbr: 'c',
      aliases: ['parallel'],
    );
    final disableConcurrency = concurrent == false;

    if (disableConcurrency) {
      logger.warn('Disabling all concurrent runs');
    }

    final validateResult = await validate(keys);
    if (validateResult != null) {
      return validateResult;
    }

    final result = commandsToRun(keys, listOut: listOut).single;

    if (printOnly) {
      result.commands?.forEach((e) {
        logger
          ..write(e.command)
          ..write('\n')
          ..write(cyan.wrap('---' * 8))
          ..write('\n')
          ..write('\n');
      });
      return ExitCode.success;
    }

    if (result.exitCode case final ExitCode exitCode) {
      return exitCode;
    }

    assert(result.commands != null, 'commands should not be null');

    final bail = result.bail ^ args.get<bool>('bail', defaultValue: false);

    Future<ExitCode> runCommands() => _runCommands(
      bail: bail,
      concurrent: concurrent ?? false,
      disableConcurrency: disableConcurrency,
      commands: result.commands ?? [],
      combinedEnvConfig: result.combinedEnvConfig,
    );

    if (neverQuit) {
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

    return runCommands();
  }

  Future<ExitCode> _runCommands({
    required bool bail,
    required bool concurrent,
    required bool disableConcurrency,
    required List<CommandToRun> commands,
    required EnvConfig? combinedEnvConfig,
  }) async {
    if (combinedEnvConfig case EnvConfig()) {
      if (combinedEnvConfig.commands case final Iterable<String> commands
          when commands.isNotEmpty) {
        logger.detail('Running env commands');

        logger.detail('Disabling concurrent runs: $disableConcurrency');

        final commandsToRun = [
          for (final command in commands)
            CommandToRun(
              command: command,
              workingDirectory: combinedEnvConfig.workingDirectory,
              keys: const [],
              runConcurrently: !disableConcurrency,
            ),
        ];

        final result = await runManyScripts.run(
          bail: true,
          label: 'Preparing env',
          sequentially: disableConcurrency,
          commands: commandsToRun.toList(),
        );

        if (result.hasFailures) {
          logger.err('Failed to run env commands');

          result.printErrors(commandsToRun, logger);

          return result.exitCode(logger);
        }
      }
    }

    if (bail) {
      logger.warn('Bail is set, stopping on first error');
    }

    if (!disableConcurrency && concurrent) {
      final exitCodes = await runManyScripts.run(
        commands: commands,
        bail: bail,
        sequentially: false,
      );

      exitCodes.printErrors(commands, logger);

      return exitCodes.exitCode(logger);
    }

    ExitCode? failureExitCode;

    ExitCode? tryBail(
      List<CommandResult> exitCodes,
      List<CommandToRun> commands,
    ) {
      logger.detail('Checking for bail ($bail), bail: ${exitCodes.join('\n')}');

      final exitCode = exitCodes.exitCode(logger);

      if (exitCode == ExitCode.success) return null;
      failureExitCode ??= exitCode;

      if (!bail) return null;

      logger.err('Bailing...');
      logger.write('\n');

      return exitCode;
    }

    final concurrentRuns = <CommandToRun>[];
    Future<ExitCode?> runMany() async {
      if (concurrentRuns.isEmpty) return null;

      logger.write(darkGray.wrap('---'));

      final exitCodes = await runManyScripts.run(
        commands: concurrentRuns.toList(),
        bail: bail,
        sequentially: false,
      );

      exitCodes.printErrors(concurrentRuns, logger);

      final bailExitCode = tryBail(exitCodes, concurrentRuns);
      concurrentRuns.clear();

      logger.write('\n');

      return bailExitCode;
    }

    Future<ExitCode> runScripts() async {
      for (var i = 0; i < commands.length; i++) {
        logger.detail(cyan.wrap('INDEX: $i'));

        final command = commands.elementAt(i);

        if (!disableConcurrency) {
          if (command.runConcurrently) {
            concurrentRuns.add(command);

            if (!command.needsRunBeforeNext) {
              continue;
            }
          }

          if (concurrentRuns.isNotEmpty) {
            logger.detail('\nRUNNING MANY COMMANDS\n');

            if (await runMany() case final ExitCode exitCode) {
              return exitCode;
            }

            final nextCommandIsNotConcurrent = switch (i) {
              > 0 when i + 1 < commands.length =>
                !commands.elementAt(i + 1).runConcurrently,
              _ => false,
            };
            // no need to go back one step if the command is set
            // to run before the next
            if (!command.needsRunBeforeNext ||
                (!command.runConcurrently && nextCommandIsNotConcurrent)) {
              // Go back one step to get the command that is skipped
              i--;
              logger.detail(cyan.wrap('BACK PEDALING: $i'));
            }
            continue;
          }
        }

        logger.detail('\nRUNNING ONE COMMAND\n');

        // Run 1 single command
        logger.write(darkGray.wrap('---\n'));
        final label = switch (command.label.split('\n')) {
          [final first] => first,
          [final first, ...] => [first, '...'].join('\n'),
          [] => '',
        };

        logger.info(darkGray.wrap(label));

        final exitCode = await runOneScript.run(
          command: command,
          showOutput: true,
        );

        exitCode.printError(command, logger);

        logger.detail('Ran script, exiting with: $exitCode');

        if (tryBail([exitCode], [command]) case final ExitCode bailCode) {
          return bailCode;
        }

        logger.write('\n');
      }

      if (await runMany() case final ExitCode exitCode) {
        return exitCode;
      }

      return failureExitCode ?? ExitCode.success;
    }

    final stopwatch = Stopwatch()..start();

    final exitCode = await runScripts();

    final time = (stopwatch..stop()).format();

    logger.info(darkGray.wrap('Finished in $time'));

    if (exitCode != ExitCode.success) {
      logger.err('Finished running scripts with errors');
    } else {
      logger.detail('Success! Finished running scripts');
    }

    return exitCode;
  }
}
