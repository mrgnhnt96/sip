import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:pub_updater/pub_updater.dart';
import 'package:sip_cli/commands/list_command.dart';
import 'package:sip_cli/commands/pub_command.dart';
import 'package:sip_cli/commands/script_run_command.dart';
import 'package:sip_cli/commands/test_command/test_command.dart';
import 'package:sip_cli/commands/update_command.dart';
import 'package:sip_cli/domain/domain.dart';
import 'package:sip_cli/src/version.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/key_press_listener.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

/// The command runner for the sip command line application
class SipRunner extends CommandRunner<ExitCode> {
  SipRunner({
    required ScriptsYaml scriptsYaml,
    required PubspecLock pubspecLock,
    required PubspecYaml pubspecYaml,
    required Variables variables,
    required Bindings bindings,
    required FindFile findFile,
    required FileSystem fs,
    required CWD cwd,
    required PubUpdater pubUpdater,
    required this.logger,
  }) : super(
          'sip',
          'A command line application to handle mono-repos in dart',
        ) {
    argParser
      ..addFlag(
        'version',
        negatable: false,
        help: 'Print the current version',
      )
      ..addFlag(
        'loud',
        negatable: false,
        hide: true,
        help: 'Prints verbose output',
      )
      ..addFlag(
        'quiet',
        negatable: false,
        hide: true,
        help: 'Prints no output',
      )
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
      ),
    );
    addCommand(
      ListCommand(
        scriptsYaml: scriptsYaml,
        logger: logger,
      ),
    );
    addCommand(
      updateCommand = UpdateCommand(
        pubUpdater: pubUpdater,
        logger: logger,
      ),
    );
    addCommand(
      TestCommand(
        pubspecYaml: pubspecYaml,
        pubspecLock: pubspecLock,
        findFile: findFile,
        bindings: bindings,
        fs: fs,
        logger: logger,
        keyPressListener: KeyPressListener(logger: logger),
      ),
    );
  }

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

        if (first == 'test' && second != null && second.startsWith('-')) {
          logger.detail('Inserting `run` to args list for `test` command');
          // insert `run` to 2nd position
          argsToUse.insert(1, 'run');
        }
      }

      final argResults = parse(argsToUse);

      logger.detail('VERSION CHECK: ${argResults['version-check']}');

      exitCode = await runCommand(argResults);
    } catch (error, stack) {
      logger
        ..err('$error')
        ..detail('$stack');
      exitCode = ExitCode.software;
    } finally {
      if (args.first != 'update') {
        final anyResult = (AnyArgParser()
              ..addFlag(
                'version-check',
                defaultsTo: true,
              ))
            .parse(args);

        if (anyResult['version-check'] as bool) {
          logger.detail('Checking for updates');
          await checkForUpdate();
        } else {
          logger.detail('Skipping version check');
        }
      } else {
        logger.detail('Skipping version check');
      }
    }

    return exitCode;
  }

  Future<void> checkForUpdate() async {
    // don't wait on this, stop after 1 second
    final exiter = Completer<({(bool, String)? result, bool exit})>();

    Timer? timer;

    timer = Timer(const Duration(seconds: 1), () {
      exiter.complete((result: null, exit: true));
    });

    updateCommand.needsUpdate().then((value) {
      exiter.complete((result: value, exit: false));
    }).ignore();

    final (:result, :exit) = await exiter.future;
    timer.cancel();

    if (exit) {
      logger.detail('Skipping version check, timeout reached');
      return;
    }

    final (needsUpdate, latestVersion) = result!;

    if (needsUpdate) {
      const changelog =
          'https://github.com/mrgnhnt96/sip/blob/main/packages/sip/CHANGELOG.md';

      final package = cyan.wrap('sip_cli');
      final currentVersion = red.wrap(packageVersion);
      final updateToVersion = green.wrap(latestVersion);
      final updateCommand = yellow.wrap('sip update');
      final changelogLink = darkGray.wrap('Changelog: $changelog');

      final message = '''
 ┌─────────────────────────────────────────────────────────────────────────────────┐ 
 │ New update for $package is available!                                            │ 
 │ You are using $currentVersion, the latest is $updateToVersion.                                       │ 
 │ Run `$updateCommand` to update to the latest version.                               │ 
 │ $changelogLink │ 
 └─────────────────────────────────────────────────────────────────────────────────┘ 
''';

      logger.write(message);
    }
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
