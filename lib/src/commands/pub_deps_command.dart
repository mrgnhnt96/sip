import 'package:sip_cli/src/commands/a_pub_command.dart';
import 'package:sip_cli/src/deps/args.dart';

/// The `pub deps` command.
///
/// https://github.com/dart-lang/pub/blob/master/lib/src/command/deps.dart
class PubDepsCommand extends APubCommand {
  const PubDepsCommand() : super(runConcurrently: false);

  @override
  String get usage =>
      '''
${super.usage}
  --separated             Run command separately for Dart and Flutter projects.
  --style, -s             How output should be displayed.
                            Allowed values: compact, tree, list
                            Default: tree
  --dev                   Whether to include dev dependencies.
  --executables           List all available executables.
  --json                  Output dependency information in a json format.

''';

  @override
  String get name => 'deps';

  @override
  String get description => 'Print package dependencies.';

  String? get style => switch (args.getOrNull<String>('style', abbr: 's')) {
    'compact' => '--style=compact',
    'tree' => '--style=tree',
    'list' => '--style=list',
    _ => null,
  };

  @override
  List<String> get pubFlags => [
    if (style case final String style) style,
    if (args.get<bool>('dev', defaultValue: true)) '--dev',
    if (args.get<bool>('executables', defaultValue: false)) '--executables',
    if (args.get<bool>('json', defaultValue: false)) '--json',
  ];
}
