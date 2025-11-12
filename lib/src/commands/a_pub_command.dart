import 'dart:math';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/deps/script_runner.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/utils/dart_or_flutter_mixin.dart';

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

  Future<Iterable<String>> pubspecs({required bool recursive}) async {
    return await pubspecYaml.all(recursive: recursive);
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
          defaultValue: false,
        ) ==
        true;
    final separated = args.get<bool>('separated', defaultValue: false);

    warnDartOrFlutter(isDartOnly: dartOnly, isFlutterOnly: flutterOnly);

    final pubspecs = await this.pubspecs(recursive: recursive);

    if (pubspecs.isEmpty) {
      logger.err('No pubspec.yaml files found.');
      return ExitCode.unavailable;
    }

    final commands = resolveFlutterAndDart(
      pubspecs,
      dartOnly: dartOnly,
      flutterOnly: flutterOnly,
      (flutterOrDart) {
        final project = path.dirname(flutterOrDart.pubspecYaml);

        final relativeDir = path.relative(
          project,
          from: fs.currentDirectory.path,
        );

        final tool = flutterOrDart.tool();

        final padding = max('flutter'.length, tool.length) - tool.length;
        var toolString = '(${cyan.wrap(tool)})';
        toolString = darkGray.wrap(toolString) ?? toolString;
        toolString = toolString.padRight(padding + toolString.length);

        var pathString = './$relativeDir';
        pathString = lightYellow.wrap(pathString) ?? pathString;

        final label = '$toolString $pathString';

        final command = ScriptToRun(
          '$tool pub $name ${pubFlags.join(' ')}'.trim(),
          workingDirectory: project,
          label: label,
          bail: bail,
          runInParallel: true,
        );

        return command;
      },
    );

    if (dartOnly && commands.dart.isEmpty) {
      logger.err('No Dart projects found.');
      return ExitCode.unavailable;
    }

    if (flutterOnly && commands.flutter.isEmpty) {
      logger.err('No Flutter projects found.');
      return ExitCode.unavailable;
    }

    if (!disableConcurrency) {
      final runners = <(Iterable<ScriptToRun>, Future<CommandResult>)>[
        if (separated) ...[
          if (commands.dart.isNotEmpty)
            (
              commands.dart,
              scriptRunner.run(
                commands.dart.toList(),
                bail: bail,
                showOutput: false,
              ),
            ),
          if (commands.flutter.isNotEmpty)
            (
              commands.flutter,
              scriptRunner.run(
                commands.flutter.toList(),
                bail: bail,
                showOutput: false,
              ),
            ),
        ] else
          (
            commands.ordered.map((e) => e.$2),
            scriptRunner.run(
              commands.ordered.map((e) => e.$2).toList(),
              bail: bail,
              showOutput: false,
              disableConcurrency: disableConcurrency,
            ),
          ),
      ];

      ExitCode? exitCode;
      for (final (_, runner) in runners) {
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

    // TODO: add label
    logger.info('\nRunning something...');

    final result = await scriptRunner.run(
      commands.ordered.map((e) => e.$2).toList(),
      bail: bail,
    );

    return result.exitCodeReason;
  }
}
