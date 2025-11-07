// ignore_for_file: cascade_invocations

import 'package:sip_cli/src/commands/a_pub_command.dart';
import 'package:sip_cli/src/deps/args.dart';

/// The `pub downgrade` command.
///
/// https://github.com/dart-lang/pub/blob/master/lib/src/command/downgrade.dart
class PubDowngradeCommand extends APubCommand {
  const PubDowngradeCommand();

  @override
  String get usage =>
      '''
${super.usage}
  --offline               Use cached packages instead of accessing the network.
  --dry-run, -n           Report what dependencies would change but don't change any.
  --tighten               Updates lower bounds in pubspec.yaml to match the resolved version.
''';

  @override
  String get name => 'downgrade';

  @override
  ({Duration? dart, Duration? flutter}) get retryAfter => (
    dart: const Duration(milliseconds: 750),
    flutter: const Duration(milliseconds: 4000),
  );

  @override
  List<String> get pubFlags => [
    if (args.get<bool>('offline', defaultValue: false)) '--offline',
    if (args.get<bool>('dry-run', abbr: 'n', defaultValue: false)) '--dry-run',
    if (args.get<bool>('tighten', defaultValue: false)) '--tighten',
  ];
}
