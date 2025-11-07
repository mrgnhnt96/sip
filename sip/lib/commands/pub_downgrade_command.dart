// ignore_for_file: cascade_invocations

import 'package:sip_cli/commands/a_pub_command.dart';

/// The `pub downgrade` command.
///
/// https://github.com/dart-lang/pub/blob/master/lib/src/command/downgrade.dart
class PubDowngradeCommand extends APubCommand {
  PubDowngradeCommand({
    required super.pubspecLock,
    required super.pubspecYaml,
    required super.fs,
    required super.logger,
    required super.bindings,
    required super.findFile,
    required super.scriptsYaml,
    required super.runManyScripts,
    required super.runOneScript,
  }) {
    argParser.addFlag(
      'offline',
      help: 'Use cached packages instead of accessing the network.',
    );

    argParser.addFlag(
      'dry-run',
      abbr: 'n',
      negatable: false,
      help: "Report what dependencies would change but don't change any.",
    );

    argParser.addFlag(
      'tighten',
      help:
          'Updates lower bounds in pubspec.yaml to match the resolved version.',
      negatable: false,
    );
  }

  @override
  String get name => 'downgrade';

  @override
  ({Duration? dart, Duration? flutter}) get retryAfter => (
    dart: const Duration(milliseconds: 750),
    flutter: const Duration(milliseconds: 4000),
  );

  @override
  List<String> get pubFlags => [
    if (argResults?['offline'] case true) '--offline',
    if (argResults?['dry-run'] case true) '--dry-run',
    if (argResults?['tighten'] case true) '--tighten',
  ];
}
