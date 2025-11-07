import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';

mixin DartOrFlutterMixin {
  Logger get logger;
  PubspecLock get pubspecLock;
  FindFile get findFile;
  FileSystem get fs;
  ScriptsYaml get scriptsYaml;

  void warnDartOrFlutter({
    required bool isFlutterOnly,
    required bool isDartOnly,
  }) {
    if (isDartOnly || isFlutterOnly) {
      if (isDartOnly && !isFlutterOnly) {
        logger.info('Running only in dart packages');
      } else if (isFlutterOnly && !isDartOnly) {
        logger.info('Running only in flutter packages');
      } else {
        logger.info('Running both dart and flutter');
      }
    }
  }

  ({
    Iterable<T> dart,
    Iterable<T> flutter,
    Iterable<(DetermineFlutterOrDart, T)> ordered,
  })
  resolveFlutterAndDart<T>(
    Iterable<String> pubspecs,
    T Function(DetermineFlutterOrDart flutterOrDart) getCommandToRun, {
    required bool dartOnly,
    required bool flutterOnly,
  }) {
    final commands = (
      dart: <T>[],
      flutter: <T>[],
      ordered: <(DetermineFlutterOrDart, T)>[],
    );

    for (final pubspec in pubspecs) {
      final flutterOrDart = DetermineFlutterOrDart(
        pubspecYaml: pubspec,
        pubspecLock: pubspecLock,
        findFile: findFile,
        scriptsYaml: scriptsYaml,
      );

      final project = path.dirname(pubspec);

      final relativeDir = path.relative(
        project,
        from: fs.currentDirectory.path,
      );

      if (dartOnly ^ flutterOnly) {
        if (dartOnly && flutterOrDart.isFlutter) {
          logger.detail('Skipping flutter project: $relativeDir');
          continue;
        } else if (flutterOnly && flutterOrDart.isDart) {
          logger.detail('Skipping dart project: $relativeDir');
          continue;
        }
      }

      final command = getCommandToRun(flutterOrDart);

      commands.ordered.add((flutterOrDart, command));
      if (flutterOrDart.isFlutter) {
        commands.flutter.add(command);
      } else {
        commands.dart.add(command);
      }
    }

    return commands;
  }
}
