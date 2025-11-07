import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:pub_updater/pub_updater.dart';
import 'package:sip_cli/commands/clean_command.dart';
import 'package:sip_cli/commands/list_command.dart';
import 'package:sip_cli/commands/pub_command.dart';
import 'package:sip_cli/commands/script_run_command.dart';
import 'package:sip_cli/commands/test_command/test_command.dart';
import 'package:sip_cli/commands/update_command.dart';
import 'package:sip_cli/domain/domain.dart';
import 'package:sip_cli/src/version.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/key_press_listener.dart';

/// The command runner for the sip command line application
class SipRunner extends CommandRunner<ExitCode> {
  SipRunner({
    required this.ogArgs,
    required ScriptsYaml scriptsYaml,
    required PubspecLock pubspecLock,
    required PubspecYaml pubspecYaml,
    required Variables variables,
    required Bindings bindings,
    required FindFile findFile,
    required FileSystem fs,
    required CWD cwd,
    required PubUpdater pubUpdater,
    required RunOneScript runOneScript,
    required RunManyScripts runManyScripts,
    required KeyPressListener keyPressListener,
    required this.logger,
  }) : super('sip', 'A command line application to handle mono-repos in dart') {
    argParser
      ..addFlag('version', negatable: false, help: 'Print the current version')
      ..addFlag(
        'loud',
        negatable: false,
        hide: true,
        help: 'Prints verbose output',
      )
      ..addFlag('quiet', negatable: false, hide: true, help: 'Prints no output')
      ..addFlag(
        'version-check',
        defaultsTo: true,
        help: 'Checks for the latest version of sip_cli',
      );

    addCommand(
      ScriptRunCommand(
        scriptsYaml: scriptsYaml,
        variables: variables,
        bindings: bindings,
        logger: logger,
        cwd: cwd,
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
      ),
    );
    addCommand(
      PubCommand(
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
        findFile: findFile,
        fs: fs,
        logger: logger,
        bindings: bindings,
        scriptsYaml: scriptsYaml,
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
      ),
    );
    addCommand(
      CleanCommand(
        pubspecYaml: pubspecYaml,
        pubspecLock: pubspecLock,
        findFile: findFile,
        bindings: bindings,
        logger: logger,
        cwd: cwd,
        scriptsYaml: scriptsYaml,
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
      ),
    );
    addCommand(ListCommand(scriptsYaml: scriptsYaml, logger: logger));
    addCommand(
      updateCommand = UpdateCommand(pubUpdater: pubUpdater, logger: logger),
    );
    addCommand(
      TestCommand(
        pubspecYaml: pubspecYaml,
        pubspecLock: pubspecLock,
        findFile: findFile,
        bindings: bindings,
        fs: fs,
        logger: logger,
        keyPressListener: keyPressListener,
        scriptsYaml: scriptsYaml,
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
      ),
    );
  }

  final List<String> ogArgs;
  final Logger logger;
  late final UpdateCommand updateCommand;

  @override
  Future<ExitCode> run(Iterable<String> args) async {
    ExitCode exitCode;

    try {
      logger.detail('Received args: $args');

      final argsToUse = [...args];

      if (args.isNotEmpty) {
        logger.detail('Checking for test command');
        final first = argsToUse.first;
        final second = argsToUse.length > 1 ? argsToUse[1] : null;

        if (first == 'test' &&
            (second == null ||
                second.startsWith('-') ||
                second.startsWith('.${path.separator}') ||
                second.startsWith('test${path.separator}'))) {
          logger.detail('Inserting `run` to args list for `test` command');
          // insert `run` to 2nd position
          argsToUse.insert(1, 'run');
        }
      }

      final argResults = argParser.parse(argsToUse);

      logger.detail('VERSION CHECK: ${argResults['version-check']}');

      exitCode = await runCommand(argResults);
    } catch (error, stack) {
      logger
        ..err('$error')
        ..detail('$stack');
      exitCode = ExitCode.software;
    } finally {
      if (ogArgs case ['update', ...]) {
        logger.detail('Skipping version check');
      } else if (ogArgs.contains('--no-version-check')) {
        logger.detail('Skipping version check');
      } else {
        logger.detail('Checking for updates');
        await updateCommand.checkForUpdate();
      }
    }

    return exitCode;
  }

  @override
  Future<ExitCode> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.wasParsed('version')) {
      logger.info(packageVersion);

      return ExitCode.success;
    }

    final result = await super.runCommand(topLevelResults);

    logger.detail('Ran sip command, exit code: $result');

    return result ?? ExitCode.success;
  }
}
