// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:sip_cli/src/commands/a_pub_command.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:yaml/yaml.dart';

/// The `pub upgrade` command.
///
/// https://github.com/dart-lang/pub/blob/master/lib/src/command/upgrade.dart
class PubUpgradeCommand extends APubCommand {
  const PubUpgradeCommand();

  @override
  String get usage =>
      '''
${super.usage}
  --offline               Use cached packages instead of accessing the network.
  --dry-run, -n           Report what dependencies would change but don't change any.
  --precompile            Precompile executables in immediate dependencies.
  --tighten               Updates lower bounds in pubspec.yaml to match the resolved version.
  --major-versions        Upgrades packages to their latest resolvable versions, and updates pubspec.yaml.
  --unlock-transitive     Also upgrades the transitive dependencies of the listed [dependencies]
''';

  @override
  String get name => 'upgrade';

  String? get majorVersions => switch (args.getOrNull<bool>(
    'major-versions',
    aliases: ['major', 'majors'],
    defaultValue: false,
  )) {
    true => '--major-versions',
    _ => null,
  };

  String? get unlockTransitive =>
      switch (args.getOrNull<bool>('unlock-transitive', defaultValue: false)) {
        true => '--unlock-transitive',
        _ => null,
      };

  @override
  List<String> get pubFlags => [
    if (args.get<bool>('offline', defaultValue: false)) '--offline',
    if (args.get<bool>('dry-run', abbr: 'n', defaultValue: false)) '--dry-run',
    if (args.get<bool>('precompile', defaultValue: false)) '--precompile',
    if (args.get<bool>('tighten', defaultValue: false)) '--tighten',
    if (majorVersions case final String majorVersions) majorVersions,
    if (unlockTransitive case final String unlockTransitive) unlockTransitive,
    if (args.rest case final rest when rest.isNotEmpty) ...rest,
  ];

  @override
  Future<Iterable<String>> pubspecs({required bool recursive}) async {
    final packages = {...args.rest};
    final pubspecs = await super.pubspecs(recursive: recursive);

    if (packages.isEmpty) {
      return pubspecs;
    }

    final files = pubspecs.map(File.new);

    // read the pubspec.yaml file
    final pubspecYamls = await Future.wait(files.map((e) => e.readAsString()));

    Iterable<String> pubspecsWithDependencies() sync* {
      for (final (index, content) in pubspecYamls.indexed) {
        final yaml = loadYaml(content) as YamlMap;

        final dependencies = {
          ...?yaml['dependencies'] as YamlMap?,
          ...?yaml['dev_dependencies'] as YamlMap?,
        };

        final dependencyKeys = dependencies.keys.cast<String>().toSet();

        if (packages.intersection(dependencyKeys).isNotEmpty) {
          yield pubspecs.elementAt(index);
        }
      }
    }

    return pubspecsWithDependencies();
  }
}
