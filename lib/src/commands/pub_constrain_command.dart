import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/constrain_pubspec_versions.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/domain/constrain_pubspec_versions.dart';
import 'package:sip_cli/src/utils/dart_or_flutter_mixin.dart';

const _usage = '''
Usage: sip pub constrain [options] [packages] [arguments]

Constrain all versions in pubspec.yaml to the current versions.

Options:
  --recursive, -r                  Run command recursively in all subdirectories.
  --dry-run, -n                    Report what dependencies would change but don't change any.
  --dev_dependencies, --dev, -d    Constrain dev_dependencies as well.
  --bump                           Bump the type of version constraint.
  --pin                            Pin the version of the package (^1.0.0 -> 1.0.0) or unpin it (1.0.0 -> ^1.0.0).
  --dart-only                      Only run command in Dart projects.
  --flutter-only                   Only run command in Flutter projects.
''';

class PubConstrainCommand with DartOrFlutterMixin {
  const PubConstrainCommand();

  /// Returns a list of packages and their versions (if specified).
  Iterable<(String, String?)> packages(List<String> packages) sync* {
    for (final package in packages) {
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

  Future<ExitCode> run() async {
    if (args.get<bool>('help', defaultValue: false)) {
      logger.write(_usage);
      return ExitCode.success;
    }

    final packages = this.packages(args.rest).toList();

    final recursive = args.get<bool>(
      'recursive',
      abbr: 'r',
      defaultValue: false,
    );
    final dartOnly = args.get<bool>('dart-only', defaultValue: false);
    final flutterOnly = args.get<bool>('flutter-only', defaultValue: false);
    final includeDevDependencies = args.get<bool>(
      'dev_dependencies',
      aliases: ['dev'],
      abbr: 'd',
      defaultValue: false,
    );
    final versionBump = VersionBump.values.byName(
      args.get<String>('bump', defaultValue: 'breaking'),
    );
    final dryRun = args.get<bool>('dry-run', abbr: 'n', defaultValue: false);
    final pin = args.getOrNull<bool>('pin');

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
}
