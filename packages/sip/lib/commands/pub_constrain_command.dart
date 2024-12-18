import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/constrain_pubspec_versions.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/utils/dart_or_flutter_mixin.dart';
import 'package:sip_cli/utils/exit_code.dart';

class PubConstrainCommand extends Command<ExitCode> with DartOrFlutterMixin {
  PubConstrainCommand({
    required this.logger,
    required this.pubspecLock,
    required this.pubspecYaml,
    required this.bindings,
    required this.fs,
    required this.findFile,
    required this.constrainPubspecVersions,
    required this.scriptsYaml,
  }) {
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
        negatable: false,
        help: 'Constrain dev_dependencies as well.',
      )
      ..addOption(
        'bump',
        help: 'Bump the type of version constraint.',
        allowed: [
          for (final type in VersionBump.values) type.name,
        ],
        defaultsTo: VersionBump.breaking.name,
      )
      ..addFlag(
        'pin',
        negatable: false,
        help: 'Pin the version of the package.',
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
  final Logger logger;
  @override
  final PubspecLock pubspecLock;
  final PubspecYaml pubspecYaml;
  final Bindings bindings;
  @override
  final FileSystem fs;
  @override
  final FindFile findFile;
  @override
  final ScriptsYaml scriptsYaml;
  final ConstrainPubspecVersions constrainPubspecVersions;

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

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final argResults = args != null ? argParser.parse(args) : this.argResults!;

    final packages = {...argResults.rest};

    final recursive = argResults['recursive'] as bool;
    final dartOnly = argResults['dart-only'] as bool;
    final flutterOnly = argResults['flutter-only'] as bool;
    final includeDevDependencies = argResults['dev_dependencies'] as bool;
    final versionBump = VersionBump.values.byName(argResults['bump'] as String);
    final dryRun = argResults['dry-run'] as bool;
    final pin = argResults['pin'] as bool;

    warnDartOrFlutter(
      isDartOnly: dartOnly,
      isFlutterOnly: flutterOnly,
    );

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

        final progress =
            logger.progress('Constraining ${cyan.wrap(relativeDir)}');

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
