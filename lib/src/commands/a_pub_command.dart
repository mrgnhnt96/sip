import 'dart:math';

import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/deps/run_many_scripts.dart';
import 'package:sip_cli/src/deps/run_one_script.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/command_to_run.dart';
import 'package:sip_cli/src/utils/dart_or_flutter_mixin.dart';
import 'package:sip_cli/src/utils/exit_code.dart';
import 'package:sip_cli/src/utils/exit_code_extensions.dart';

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
  --[no-]concurrent, -c   Run command concurrently.
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
    final concurrent = args.get<bool>(
      'concurrent',
      abbr: 'c',
      aliases: ['parallel'],
      defaultValue: runConcurrently,
    );
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

        final command = CommandToRun(
          command: '$tool pub $name ${pubFlags.join(' ')}',
          workingDirectory: project,
          keys: ['dart', 'pub', name, ...pubFlags],
          label: label,
          bail: bail,
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

    if (concurrent) {
      final label =
          'Running ${lightCyan.wrap('pub $name ${pubFlags.join(' ')}')}';

      final runners = <(Iterable<CommandToRun>, Future<List<CommandResult>>)>[
        if (separated) ...[
          if (commands.dart.isNotEmpty)
            (
              commands.dart,
              runManyScripts.run(
                label: label,
                bail: bail,
                commands: commands.dart.toList(),
                sequentially: false,
                retryAfter: retryAfter?.dart,
              ),
            ),
          if (commands.flutter.isNotEmpty)
            (
              commands.flutter,
              runManyScripts.run(
                label: label,
                bail: bail,
                commands: commands.flutter.toList(),
                sequentially: false,
                retryAfter: retryAfter?.flutter,
              ),
            ),
        ] else
          (
            commands.ordered.map((e) => e.$2),
            runManyScripts.run(
              label: label,
              bail: bail,
              commands: commands.ordered.map((e) => e.$2).toList(),
              sequentially: false,
            ),
          ),
      ];

      ExitCode? exitCode;
      for (final (commands, runner) in runners) {
        final exitCodes = await runner;

        exitCodes.printErrors(commands, logger);

        final result = exitCodes.exitCode(logger);
        if (result != ExitCode.success) {
          if (bail) {
            return result;
          }

          exitCode = result;
        }
      }

      return exitCode ?? ExitCode.success;
    }

    var exitCode = ExitCode.success;

    for (final (tool, command) in commands.ordered) {
      logger.info('\nRunning ${lightCyan.wrap(command.command)}');

      final result = await runOneScript.run(
        command: command,
        showOutput: true,
        retryAfter: tool.isDart ? retryAfter?.dart : retryAfter?.flutter,
      );

      if (result.exitCodeReason != ExitCode.success) {
        if (exitCode != ExitCode.success) {
          exitCode = result.exitCodeReason;
        }

        if (bail) {
          result.printError(command, logger);
          return exitCode;
        }
      }
    }

    return exitCode;
  }
}
