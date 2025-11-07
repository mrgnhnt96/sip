// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/domain/any_arg_parser.dart';
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_result.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/cwd.dart';
import 'package:sip_cli/domain/env_config.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/domain/variables.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';
import 'package:sip_cli/utils/run_script_helper.dart';
import 'package:sip_cli/utils/stopwatch_extensions.dart';
import 'package:sip_cli/utils/working_directory.dart';

/// The command to run a script
class ScriptRunCommand extends Command<ExitCode>
    with RunScriptHelper, WorkingDirectory {
  ScriptRunCommand({
    required this.scriptsYaml,
    required this.variables,
    required this.bindings,
    required this.logger,
    required this.cwd,
    required this.runOneScript,
    required this.runManyScripts,
  }) : argParser = AnyArgParser() {
    addFlags();

    argParser.addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Prints usage information.',
    );

    argParser.addFlag(
      'print',
      abbr: 'p',
      negatable: false,
      help: 'Prints the commands that would be run without executing them.',
    );

    argParser.addFlag('bail', negatable: false, help: 'Stop on first error');

    argParser.addFlag(
      'never-exit',
      negatable: false,
      help:
          '!!${red.wrap('USE WITH CAUTION')}!!!\n'
          'After the script is done, the command will '
          'restart after a 1 second delay.\n'
          'This is useful for long running scripts that '
          'should always be running.',
      aliases: ['never-quit'],
    );

    argParser.addFlag(
      'concurrent',
      aliases: ['parallel', 'c', 'p'],
      abbr: 'c',
      help:
          'Runs all scripts concurrently. --no-concurrent will turn off '
          'concurrency even if set in the scripts.yaml',
    );
  }

  @override
  final ArgParser argParser;

  @override
  final ScriptsYaml scriptsYaml;
  @override
  final Variables variables;
  final Bindings bindings;
  @override
  final Logger logger;
  @override
  final CWD cwd;
  final RunOneScript runOneScript;
  final RunManyScripts runManyScripts;

  @override
  String get description => 'Runs a script';

  @override
  String get name => 'run';

  @override
  List<String> get aliases => ['r'];

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final argResults = argParser.parse(args ?? this.argResults?.rest ?? []);
    final neverQuit = argResults['never-exit'] as bool? ?? false;
    final listOut = argResults['list'] as bool? ?? false;
    final printOnly = argResults['print'] as bool? ?? false;

    if (argResults['help'] as bool? ?? false) {
      printUsage();
      return ExitCode.success;
    }

    final keys = args ?? argResults.rest;

    final concurrent = argResults['concurrent'] == true;
    final disableConcurrency =
        argResults.wasParsed('concurrent') && !concurrent;

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

    final bail = result.bail ^ (argResults['bail'] as bool? ?? false);

    Future<ExitCode> runCommands() => _runCommands(
      argResults: argResults,
      bail: bail,
      concurrent: concurrent,
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
    required ArgResults argResults,
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

        final noConcurrent = argResults.arguments.contains('--no-concurrent');
        logger.detail('Disabling concurrent runs: $noConcurrent');

        final commandsToRun = [
          for (final command in commands)
            CommandToRun(
              command: command,
              workingDirectory: combinedEnvConfig.workingDirectory,
              keys: const [],
              runConcurrently: !noConcurrent,
            ),
        ];

        final result = await runManyScripts.run(
          bail: true,
          label: 'Preparing env',
          sequentially: noConcurrent,
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

    logger.detail(cyan.wrap('RUNNING ONE COMMAND?'));

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
