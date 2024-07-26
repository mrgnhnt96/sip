// ignore_for_file: cascade_invocations

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/domain/any_arg_parser.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';
import 'package:sip_cli/utils/run_script_helper.dart';
import 'package:sip_cli/utils/stopwatch_extensions.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

/// The command to run a script
class ScriptRunCommand extends Command<ExitCode> with RunScriptHelper {
  ScriptRunCommand({
    required this.scriptsYaml,
    required this.variables,
    required this.bindings,
    required this.logger,
    required this.cwd,
  }) : argParser = AnyArgParser() {
    addFlags();

    argParser.addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Prints usage information.',
    );

    argParser.addFlag(
      'bail',
      negatable: false,
      help: 'Stop on first error',
    );

    argParser.addFlag(
      'never-exit',
      negatable: false,
      help: '!!${red.wrap('USE WITH CAUTION')}!!!\n'
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
      help: 'Runs all scripts concurrently. --no-concurrent will turn off '
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

    var (exitCode, commands, bail) = commandsToRun(keys, argResults);

    if (exitCode != null) {
      return exitCode;
    }
    assert(commands != null, 'commands should not be null');
    commands!;

    bail ^= argResults['bail'] as bool? ?? false;

    Future<ExitCode> runCommands() => _run(
          argResults: argResults,
          bail: bail,
          concurrent: concurrent,
          disableConcurrency: disableConcurrency,
          commands: commands,
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

  Future<ExitCode> _run({
    required ArgResults argResults,
    required bool bail,
    required bool concurrent,
    required bool disableConcurrency,
    required Iterable<CommandToRun> commands,
  }) async {
    if (!disableConcurrency && concurrent) {
      final exitCodes = await RunManyScripts(
        commands: commands,
        bindings: bindings,
        logger: logger,
      ).run(
        label: 'Running ${commands.length} scripts concurrently',
        bail: bail,
      );

      exitCodes.printErrors(commands, logger);

      return exitCodes.exitCode(logger);
    }

    if (bail) {
      logger.warn('Bail is set, stopping on first error');
    }

    ExitCode? failureExitCode;

    ExitCode? tryBail(List<ExitCode> exitCodes, List<CommandToRun> commands) {
      logger.detail('Checking for bail ($bail), bail: $exitCodes');

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

      final exitCodes = await RunManyScripts(
        commands: concurrentRuns,
        bindings: bindings,
        logger: logger,
      ).run(bail: bail);

      exitCodes.printErrors(concurrentRuns, logger);

      final bailExitCode = tryBail(exitCodes, concurrentRuns);
      concurrentRuns.clear();

      logger.write('\n');

      return bailExitCode;
    }

    Future<ExitCode> runScripts() async {
      for (final command in commands) {
        if (!disableConcurrency) {
          if (command.runConcurrently) {
            concurrentRuns.add(command);
            continue;
          } else if (concurrentRuns.isNotEmpty) {
            if (await runMany() case final ExitCode exitCode) {
              return exitCode;
            }
          }
        }

        logger.write(darkGray.wrap('---\n'));
        final lines = command.label.split('\n');
        String label;

        if (lines.length > 1) {
          label = [lines.first, '...'].join('\n');
        } else {
          label = command.label;
        }

        logger.info(darkGray.wrap(label));

        final exitCode = await RunOneScript(
          command: command,
          bindings: bindings,
          logger: logger,
          showOutput: true,
        ).run();

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
