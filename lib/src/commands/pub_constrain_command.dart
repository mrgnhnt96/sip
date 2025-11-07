import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/deps/constrain_pubspec_versions.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/command_to_run.dart';
import 'package:sip_cli/src/domain/constrain_pubspec_versions.dart';
import 'package:sip_cli/src/utils/dart_or_flutter_mixin.dart';
import 'package:sip_cli/src/utils/exit_code.dart';

class PubConstrainCommand extends Command<ExitCode> with DartOrFlutterMixin {
  PubConstrainCommand() {
    argParser
      ..addFlag(
        'recursive',
        abbr: 'r',
        negatable: false,
        help: 'Run command recursively in all subdirectories.',
      )
      ..addFlag(
        'dry-run',
        abbr: 'n',
        negatable: false,
        help: "Report what dependencies would change but don't change any.",
      )
      ..addFlag(
        'dev_dependencies',
        abbr: 'd',
        aliases: ['dev'],
        negatable: false,
        help: 'Constrain dev_dependencies as well.',
      )
      ..addOption(
        'bump',
        help: 'Bump the type of version constraint.',
        allowed: [for (final type in VersionBump.values) type.name],
        defaultsTo: VersionBump.breaking.name,
      )
      ..addFlag(
        'pin',
        help:
            'Pin the version of the package (^1.0.0 -> 1.0.0). '
            'Unpins otherwise (1.0.0 -> ^1.0.0)',
        defaultsTo: null,
      )
      ..addFlag(
        'dart-only',
        negatable: false,
        help: 'Only run command in Dart projects.',
      )
      ..addFlag(
        'flutter-only',
        negatable: false,
        help: 'Only run command in Flutter projects.',
      );
  }

  @override
  String get name => 'constrain';

  @override
  String get description =>
      'Constrain all versions in pubspec.yaml to the current versions.';

  @override
  String get invocation {
    final invocation = super.invocation;

    final first = invocation.split(' [arguments]').first;

    return '$first [packages] [arguments]';
  }

  /// Returns a list of packages and their versions (if specified).
  Iterable<(String, String?)> packages(ArgResults argResults) sync* {
    for (final package in argResults.rest) {
      final version = package.split(':');
      switch (version) {
        case [final String package, final String version]:
          yield (package, version);
        case [final String package]:
          yield (package, null);
        default:
          throw ArgumentError('Invalid package: $package');
      }
    }
  }

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final argResults = args != null ? argParser.parse(args) : this.argResults!;

    final packages = this.packages(argResults).toList();

    final recursive = argResults['recursive'] as bool;
    final dartOnly = argResults['dart-only'] as bool;
    final flutterOnly = argResults['flutter-only'] as bool;
    final includeDevDependencies = argResults['dev_dependencies'] as bool;
    final versionBump = VersionBump.values.byName(argResults['bump'] as String);
    final dryRun = argResults['dry-run'] as bool;
    final pin = argResults['pin'] as bool?;

    warnDartOrFlutter(isDartOnly: dartOnly, isFlutterOnly: flutterOnly);

    final pubspecs = await pubspecYaml.all(recursive: recursive);

    if (pubspecs.isEmpty) {
      logger.err('No pubspec.yaml files found.');
      return ExitCode.unavailable;
    }

    resolveFlutterAndDart(
      pubspecs,
      dartOnly: dartOnly,
      flutterOnly: flutterOnly,
      (flutterOrDart) {
        final project = path.dirname(flutterOrDart.pubspecYaml);

        final relativeDir = path.relative(
          project,
          from: fs.currentDirectory.path,
        );

        final progress = logger.progress(
          'Constraining ${cyan.wrap(relativeDir)}',
        );

        final success = constrainPubspecVersions.constrain(
          flutterOrDart.pubspecYaml,
          includeDevDependencies: includeDevDependencies,
          bump: versionBump,
          dryRun: dryRun,
          packages: packages,
          pin: pin,
        );

        progress.complete();

        logger.flush();

        return success;
      },
    );

    return ExitCode.success;
  }

  CommandToRun getCommandToRun(String pubspec) {
    return CommandToRun(
      command: 'pub',
      keys: const [],
      workingDirectory: pubspec,
    );
  }
}
