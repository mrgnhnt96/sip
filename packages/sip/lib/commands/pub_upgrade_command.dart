// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:sip_cli/commands/a_pub_command.dart';
import 'package:yaml/yaml.dart';

/// The `pub upgrade` command.
///
/// https://github.com/dart-lang/pub/blob/master/lib/src/command/upgrade.dart
class PubUpgradeCommand extends APubCommand {
  PubUpgradeCommand({
    required super.pubspecLock,
    required super.pubspecYaml,
    required super.bindings,
    required super.findFile,
    required super.fs,
    required super.logger,
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
      'precompile',
      help: 'Precompile executables in immediate dependencies.',
    );

    argParser.addFlag(
      'tighten',
      help:
          'Updates lower bounds in pubspec.yaml to match the resolved version.',
      negatable: false,
    );

    argParser.addFlag(
      'unlock-transitive',
      help: 'Also upgrades the transitive dependencies '
          'of the listed [dependencies]',
      negatable: false,
    );

    argParser.addFlag(
      'major-versions',
      help: 'Upgrades packages to their latest resolvable versions, '
          'and updates pubspec.yaml.',
      aliases: ['major', 'majors'],
      negatable: false,
    );
  }

  @override
  String get name => 'upgrade';

  @override
  List<String> get pubFlags => [
        if (argResults!['offline'] as bool) '--offline',
        if (argResults!['dry-run'] as bool) '--dry-run',
        if (argResults!['precompile'] as bool) '--precompile',
        if (argResults!['tighten'] as bool) '--tighten',
        if (argResults!['major-versions'] as bool) '--major-versions',
        if (argResults!['unlock-transitive'] as bool) '--unlock-transitive',
        if (argResults!.rest.isNotEmpty) ...argResults!.rest,
      ];

  @override
  List<String> get aliases => ['up', 'update'];

  @override
  Future<Iterable<String>> pubspecs({required bool recursive}) async {
    final packages = {...?argResults?.rest};
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
