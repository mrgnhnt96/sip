import 'dart:async';

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/commands/clean_command.dart';
import 'package:sip_cli/src/commands/list_command.dart';
import 'package:sip_cli/src/commands/pub_command.dart';
import 'package:sip_cli/src/commands/script_run_command.dart';
import 'package:sip_cli/src/commands/test_command/test_command.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/is_up_to_date.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/version.dart';

const _usage = '''
A command line application to handle mono-repos in dart

Usage: sip <command>

Commands:
  clean       Clean the project
  list, ls    List all scripts
  pub         Modify dependencies in pubspec.yaml file
  run, r      Runs a script
  version     Print the current version
  update      Update the sip command line application
  test        Run tests

Flags:
  --version   Print the current version
  --help      Print usage information
''';

/// The command runner for the sip command line application
class SipRunner {
  const SipRunner();

  Future<ExitCode> run() async {
    ExitCode exitCode;

    final versionCheck = args.get<bool>('version-check', defaultValue: true);

    try {
      logger
        ..detail('Received args: $args')
        ..detail('VERSION CHECK: $versionCheck');

      exitCode = await runCommand();
    } catch (error, stack) {
      logger
        ..err('$error')
        ..detail('$stack');
      exitCode = ExitCode.software;
    } finally {
      if (args.path case ['update', ...]) {
        logger.detail('Skipping version check');
      } else if (!versionCheck) {
        logger.detail('Skipping version check');
      } else {
        logger.detail('Checking for updates');
        if (!await isUpToDate.check()) {
          final latestVersion = await isUpToDate.latestVersion();
          logger.info(
            'A new version is available ($latestVersion). '
            'Run `sip update` to update.',
          );
        }
      }
    }

    return exitCode;
  }

  Future<ExitCode> runCommand() async {
    if (args.get<bool>('help', defaultValue: false) && args.path.isEmpty) {
      logger.write(_usage);
      return ExitCode.success;
    }

    if (args['version'] case true) {
      logger.info(packageVersion);
      return ExitCode.success;
    }

    switch (args.path) {
      case ['run' || 'r', ...final path]:
        return await const ScriptRunCommand().run(path);
      case ['pub', ...final path]:
        return await const PubCommand().run(path);
      case ['clean']:
        return await const CleanCommand().run();
      case ['list' || 'ls', ...final query]:
        return await const ListCommand().run(query);
      case ['test', ...final path]:
        return await const TestCommand().run(path);
    }

    logger.write(_usage);

    return ExitCode.usage;
  }
}
