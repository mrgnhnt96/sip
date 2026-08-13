import 'dart:async';

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/commands/ai/ai_command.dart';
import 'package:sip_cli/src/commands/clean_command.dart';
import 'package:sip_cli/src/commands/list_command.dart';
import 'package:sip_cli/src/commands/pub_command.dart';
import 'package:sip_cli/src/commands/script_run_command.dart';
import 'package:sip_cli/src/commands/test_command/test_command.dart';
import 'package:sip_cli/src/commands/update_command.dart';
import 'package:sip_cli/src/deps/analytics.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/is_up_to_date.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/platform.dart';
import 'package:sip_cli/src/deps/terminal.dart';
import 'package:sip_cli/src/utils/output_mode.dart';
import 'package:sip_cli/src/version.dart';

const _usage = '''
A command line application to handle mono-repos in dart

Usage: sip <command>

Commands:
  ai          Install a sip reference file for an AI coding assistant
  clean       Clean the project
  list, ls    List all scripts
  pub         Modify dependencies in pubspec.yaml file
  run, r      Runs a script
  version     Print the current version
  update      Update the sip command line application
  test        Run tests

Flags:
  --version           Print the current version
  --help              Print usage information
  --[no-]color        Force ANSI colour on or off (default: on when stdout is
                      a terminal; also honours NO_COLOR and FORCE_COLOR)
  --[no-]version-check
                      Check pub.dev for a newer sip (default: on when stdout
                      is a terminal; also honours SIP_NO_VERSION_CHECK)
  --quiet             Only print errors
  --loud              Print verbose output
''';

/// The command runner for the sip command line application
class SipRunner {
  const SipRunner();

  Future<ExitCode> run() async {
    ExitCode exitCode;

    final versionCheck = shouldCheckVersion(
      args: args,
      environment: platform.environment,
      hasTerminal: terminal.hasTerminal,
    );

    if (args['disable-analytics'] case true) {
      analytics.disable();
    }

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
          // stderr, so it never lands in output somebody is capturing.
          logger.warn(
            'A new version is available ($latestVersion). '
            'Run `sip update` to update.',
            tag: '',
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
      case ['ai', ...final path]:
        return await const AiCommand().run(path);
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
      case ['update']:
        return await const UpdateCommand().run();
    }

    logger.write(_usage);

    return ExitCode.usage;
  }
}
