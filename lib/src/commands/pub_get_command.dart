// ignore_for_file: cascade_invocations

import 'package:sip_cli/src/commands/a_pub_command.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/utils/package.dart';

/// The `pub get` command.
///
/// https://github.com/dart-lang/pub/blob/master/lib/src/command/get.dart
class PubGetCommand extends APubCommand {
  const PubGetCommand();

  @override
  String get name => 'get';

  @override
  String get usage =>
      '''
${super.usage}
  --offline               Use cached packages instead of accessing the network.
  --dry-run, -n           Report what dependencies would change but don't change any.
  --enforce-lockfile      Enforce pubspec.lock. Fail resolution if pubspec.lock does not satisfy pubspec.yaml
  --unlock-transitive     Also upgrades the transitive dependencies of the listed [dependencies]
  --precompile            Build executables in immediate dependencies.
''';

  @override
  ({Duration? dart, Duration? flutter}) get retryAfter => (
    dart: const Duration(milliseconds: 750),
    flutter: const Duration(milliseconds: 4000),
  );

  @override
  Future<List<Package>> packages({required bool recursive}) async {
    final pubspecs = await this.pubspecs(recursive: recursive);
    final pkgs = pubspecs.map(Package.new);

    Iterable<Package> packages() sync* {
      for (final pkg in pkgs) {
        if (pkg.isPartOfWorkspace) {
          logger.detail('Skipping workspace package: ${pkg.relativePath}');
          continue;
        }

        yield pkg;
      }
    }

    final resolved = packages().toList();

    if (resolved.isNotEmpty) {
      return resolved;
    }

    return [Package.nearest()];
  }

  @override
  List<String> get pubFlags => [
    if (args.get<bool>('offline', defaultValue: false)) '--offline',
    if (args.get<bool>('dry-run', abbr: 'n', defaultValue: false)) '--dry-run',
    if (args.get<bool>('enforce-lockfile', defaultValue: false))
      '--enforce-lockfile',
    if (args.get<bool>('precompile', defaultValue: false)) '--precompile',
  ];
}
