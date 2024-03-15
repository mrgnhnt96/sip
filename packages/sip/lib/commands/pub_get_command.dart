// ignore_for_file: cascade_invocations

import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/commands/a_pub_command.dart';
import 'package:sip_cli/utils/exit_code.dart';

/// The `pub get` command.
class PubGetCommand extends APubCommand {
  PubGetCommand({
    required super.pubspecLock,
    required super.pubspecYaml,
    required super.fs,
    required super.logger,
    required super.bindings,
    required super.findFile,
  }) {
    argParser
      ..addFlag(
        'offline',
        help: 'Use cached packages instead of accessing the network.',
      )
      ..addFlag(
        'dry-run',
        abbr: 'n',
        negatable: false,
        help: "Report what dependencies would change but don't change any.",
      )
      ..addFlag(
        'enforce-lockfile',
        negatable: false,
        help: 'Enforce pubspec.lock. Fail resolution if '
            'pubspec.lock does not satisfy pubspec.yaml',
      )
      ..addFlag(
        'precompile',
        help: 'Build executables in immediate dependencies.',
      )
      ..addFlag(
        'ignore-lockfile-exit',
        negatable: false,
        help: 'When the lockfile is out of date and `--enforce-lockfile` '
            'is used, treat the exit code as success.',
      );
  }

  @override
  String get name => 'get';

  @override
  List<String> get pubFlags => [
        if (argResults!['offline'] as bool) '--offline',
        if (argResults!['dry-run'] as bool) '--dry-run',
        if (argResults!['enforce-lockfile'] as bool) '--enforce-lockfile',
        if (argResults!['precompile'] as bool) '--precompile',
      ];

  @override
  ExitCode onFinish(ExitCode exitCode) {
    final ignoreLockfileExitCode = argResults!['ignore-lockfile-exit'] as bool;

    if (!ignoreLockfileExitCode) {
      return exitCode;
    }

    if (exitCode.code == 65) {
      logger.write('\n');
      logger.detail('Ignoring exit code 65');

      logger.warn('The lockfile is out of date');
      logger.info(
        '${green.wrap('Successfully')} ${darkGray.wrap('got dependencies.')}',
      );

      logger.write('\n');
      return ExitCode.success;
    }

    return exitCode;
  }
}
