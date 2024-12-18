// ignore_for_file: cascade_invocations

import 'package:sip_cli/commands/a_pub_command.dart';

/// The `pub get` command.
///
/// https://github.com/dart-lang/pub/blob/master/lib/src/command/get.dart
class PubGetCommand extends APubCommand {
  PubGetCommand({
    required super.pubspecLock,
    required super.pubspecYaml,
    required super.fs,
    required super.logger,
    required super.bindings,
    required super.findFile,
    required super.scriptsYaml,
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
        'unlock-transitive',
      )
      ..addFlag(
        'precompile',
        help: 'Build executables in immediate dependencies.',
      );
  }

  @override
  String get name => 'get';

  @override
  ({Duration? dart, Duration? flutter}) get retryAfter => (
        dart: const Duration(milliseconds: 750),
        flutter: const Duration(milliseconds: 4000)
      );

  @override
  List<String> get pubFlags => [
        if (argResults!['offline'] as bool) '--offline',
        if (argResults!['dry-run'] as bool) '--dry-run',
        if (argResults!['enforce-lockfile'] as bool) '--enforce-lockfile',
        if (argResults!['precompile'] as bool) '--precompile',
      ];
}
