import 'dart:math';

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/analytics.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/deps/script_runner.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/utils/dart_or_flutter_mixin.dart';
import 'package:sip_cli/src/utils/package.dart';

/// A command that runs `pub *`.
abstract class APubCommand with DartOrFlutterMixin {
  const APubCommand({this.runConcurrently = true});

  final bool runConcurrently;

  /// The name of the command.
  ///
  /// This doubles as the command used for dart and flutter.
  String get name;

  List<String> get pubFlags => [];

  ({Duration? dart, Duration? flutter})? get retryAfter => null;

  String get description => '$name dependencies for pubspec.yaml files';

  String get usage =>
      '''
Usage: sip pub $name [options]

$description

Options:
  --help                  Print usage information
  --recursive, -r         Run command recursively in all subdirectories.
  --no-concurrent         Disabled concurrency for this command.
  --bail, -b              Stop on first error.
  --dart-only             Run command only in Dart projects.
  --flutter-only          Run command only in Flutter projects.
  --separated             Run command separately for Dart and Flutter projects.
''';

  ExitCode onFinish(ExitCode exitCode) => exitCode;

  Future<ExitCode> run() async {
    if (args.get<bool>('help', defaultValue: false)) {
      logger.write(usage);
      return ExitCode.success;
    }

    final result = await _run();

    return onFinish(result);
  }

  Future<List<String>> pubspecs({required bool recursive}) async {
    return await pubspecYaml.all(recursive: recursive);
  }

  Future<List<Package>> packages({required bool recursive}) async {
    final pubspecs = await this.pubspecs(recursive: recursive);
    return pubspecs.map(Package.new).toList();
  }

  Future<ExitCode> _run() async {
    final bail = args.get<bool>('bail', abbr: 'b', defaultValue: false);
    final recursive = args.get<bool>(
      'recursive',
      abbr: 'r',
      defaultValue: false,
    );
    final dartOnly = args.get<bool>('dart-only', defaultValue: false);
    final flutterOnly = args.get<bool>('flutter-only', defaultValue: false);
    final disableConcurrency =
        args.get<bool>(
          'concurrent',
          aliases: ['parallel'],
          defaultValue: runConcurrently,
        ) ==
        false;
    final separated = args.get<bool>('separated', defaultValue: false);

    warnDartOrFlutter(isDartOnly: dartOnly, isFlutterOnly: flutterOnly);

    final pkgs = await packages(recursive: recursive);
    final commands = <ScriptToRun>[];

    await analytics.track(
      'pub_$name',
      props: {
        'bail': bail,
        'recursive': recursive,
        'dart_only': dartOnly,
        'flutter_only': flutterOnly,
        'disable_concurrency': disableConcurrency,
        'separated': separated,
        'packages_count': pkgs.length,
      },
    );

    for (final pkg in pkgs) {
      if (!pkg.shouldInclude(dartOnly: dartOnly, flutterOnly: flutterOnly)) {
        logger.detail('Skipping project: ${pkg.relativePath}');
        continue;
      }

      final tool = pkg.tool;

      final padding = max('flutter'.length, tool.length) - tool.length;
      var toolString = '(${cyan.wrap(tool)})';
      toolString = darkGray.wrap(toolString) ?? toolString;
      toolString = toolString.padRight(padding + toolString.length);

      var pathString = './${pkg.relativePath}';
      pathString = lightYellow.wrap(pathString) ?? pathString;

      final label = '$toolString $pathString';

      final command = ScriptToRun(
        '$tool pub $name ${pubFlags.join(' ')}'.trim(),
        workingDirectory: pkg.path,
        label: label,
        bail: bail,
        runInParallel: true,
        data: pkg,
      );

      commands.add(command);
    }

    if (commands.isEmpty) {
      logger.err('No projects found.');
      return ExitCode.unavailable;
    }

    final List<Future<CommandResult>> runners;
    switch (separated) {
      case true:
        final dart = <ScriptToRun>[];
        final flutter = <ScriptToRun>[];

        for (final cmd in commands) {
          if (cmd.data case Package(isDart: true)) {
            dart.add(cmd);
          } else if (cmd.data case Package(isFlutter: true)) {
            flutter.add(cmd);
          } else {
            throw Exception('Invalid package: ${cmd.data}');
          }
        }

        runners = [
          scriptRunner.run(
            dart.toList(),
            bail: bail,
            disableConcurrency: disableConcurrency,
          ),
          scriptRunner.run(
            flutter.toList(),
            bail: bail,
            disableConcurrency: disableConcurrency,
          ),
        ];

      case false:
        runners = [
          scriptRunner.run(
            commands.toList(),
            bail: bail,
            disableConcurrency: disableConcurrency,
          ),
        ];
    }

    ExitCode? exitCode;
    for (final runner in runners) {
      final result = await runner;

      if (result.exitCodeReason != ExitCode.success) {
        if (bail) {
          return result.exitCodeReason;
        }

        exitCode = result.exitCodeReason;
      }
    }

    return exitCode ?? ExitCode.success;
  }
}
