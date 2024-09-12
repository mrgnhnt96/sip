// ignore_for_file: cascade_invocations

import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';

/// A command that runs `pub *`.
abstract class APubCommand extends Command<ExitCode> {
  APubCommand({
    required this.pubspecLock,
    required this.pubspecYaml,
    required this.bindings,
    required this.findFile,
    required this.logger,
    required this.fs,
  }) {
    argParser
      ..addFlag(
        'recursive',
        abbr: 'r',
        negatable: false,
        help: 'Run command recursively in all subdirectories.',
      )
      ..addFlag(
        'concurrent',
        aliases: ['parallel'],
        abbr: 'c',
        defaultsTo: true,
        help: 'Run command concurrently in all subdirectories.',
      )
      ..addFlag(
        'bail',
        abbr: 'b',
        negatable: false,
        help: 'Stop running commands if one fails.',
      )
      ..addFlag(
        'dart-only',
        negatable: false,
        help: 'Only run command in Dart projects.',
      )
      ..addFlag(
        'separated',
        help: 'Runs concurrent dart and flutter commands separately. '
            'Does nothing if --concurrent is not enabled.',
      )
      ..addFlag(
        'flutter-only',
        negatable: false,
        help: 'Only run command in Flutter projects.',
      );
  }

  List<String> get pubFlags => [];

  final PubspecLock pubspecLock;
  final PubspecYaml pubspecYaml;
  final Bindings bindings;
  final FindFile findFile;
  final Logger logger;
  final FileSystem fs;

  ({Duration? dart, Duration? flutter})? get retryAfter => null;

  @override
  String get description => '$name dependencies for pubspec.yaml files';

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

  ExitCode onFinish(ExitCode exitCode) => exitCode;

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final result = await _run(args);

    return onFinish(result);
  }

  Future<ExitCode> _run([List<String>? args]) async {
    final argResults = args != null ? argParser.parse(args) : this.argResults!;

    final bail = argResults['bail'] as bool;
    final recursive = argResults['recursive'] as bool;
    final dartOnly = argResults['dart-only'] as bool;
    final flutterOnly = argResults['flutter-only'] as bool;
    final concurrent = argResults['concurrent'] as bool;
    final separated = argResults['separated'] as bool;

    warnDartOrFlutter(
      isDartOnly: dartOnly,
      isFlutterOnly: flutterOnly,
    );

    final pubspecs = await pubspecYaml.all(recursive: recursive);

    if (pubspecs.isEmpty) {
      logger.err('No pubspec.yaml files found.');
      return ExitCode.unavailable;
    }

    final commands = (
      dart: <CommandToRun>[],
      flutter: <CommandToRun>[],
      ordered: <(DetermineFlutterOrDart, CommandToRun)>[],
    );
    for (final pubspec in pubspecs) {
      final flutterOrDart = DetermineFlutterOrDart(
        pubspecYaml: pubspec,
        pubspecLock: pubspecLock,
        findFile: findFile,
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
      );

      commands.ordered.add((flutterOrDart, command));
      if (flutterOrDart.isFlutter) {
        commands.flutter.add(command);
      } else {
        commands.dart.add(command);
      }
    }

    if (concurrent) {
      final runners = [
        if (separated) ...[
          if (commands.dart.isNotEmpty)
            RunManyScripts(
              commands: commands.dart,
              bindings: bindings,
              logger: logger,
              retryAfter: retryAfter?.dart,
            ),
          if (commands.flutter.isNotEmpty)
            RunManyScripts(
              commands: commands.flutter,
              bindings: bindings,
              logger: logger,
              retryAfter: retryAfter?.flutter,
            ),
        ] else
          RunManyScripts(
            commands: commands.ordered.map((e) => e.$2),
            bindings: bindings,
            logger: logger,
          ),
      ];

      ExitCode? exitCode;
      for (final runner in runners) {
        final exitCodes = await runner.run(
          label: 'Running ${lightCyan.wrap('pub $name ${pubFlags.join(' ')}')}',
          bail: bail,
        );

        exitCodes.printErrors(runner.commands, logger);

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

      final result = await RunOneScript(
        command: command,
        bindings: bindings,
        logger: logger,
        showOutput: true,
        retryAfter: tool.isDart ? retryAfter?.dart : retryAfter?.flutter,
      ).run();

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
