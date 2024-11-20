// ignore_for_file: cascade_invocations

import 'package:sip_cli/commands/a_pub_command.dart';

/// The `pub deps` command.
///
/// https://github.com/dart-lang/pub/blob/master/lib/src/command/deps.dart
class PubDepsCommand extends APubCommand {
  PubDepsCommand({
    required super.pubspecLock,
    required super.pubspecYaml,
    required super.fs,
    required super.logger,
    required super.bindings,
    required super.findFile,
  }) : super(runConcurrently: false) {
    argParser.addOption(
      'style',
      abbr: 's',
      help: 'How output should be displayed.',
      allowed: ['compact', 'tree', 'list'],
      defaultsTo: 'tree',
    );

    argParser.addFlag(
      'dev',
      help: 'Whether to include dev dependencies.',
      defaultsTo: true,
    );

    argParser.addFlag(
      'executables',
      negatable: false,
      help: 'List all available executables.',
    );

    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Output dependency information in a json format.',
    );
  }

  @override
  String get name => 'deps';

  @override
  String get description => 'Print package dependencies.';

  @override
  List<String> get pubFlags => [
        if (argResults!['style'] case final String style) '--style=$style',
        if (argResults!['dev'] as bool) '--dev',
        if (argResults!['executables'] as bool) '--executables',
        if (argResults!['json'] as bool) '--json',
      ];
}
