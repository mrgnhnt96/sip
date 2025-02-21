// ignore_for_file: cascade_invocations

import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/command_result.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/utils/dart_or_flutter_mixin.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';

/// A command that runs `pub *`.
abstract class APubCommand extends Command<ExitCode> with DartOrFlutterMixin {
  APubCommand({
    required this.pubspecLock,
    required this.pubspecYaml,
    required this.bindings,
    required this.findFile,
    required this.logger,
    required this.fs,
    required this.scriptsYaml,
    required this.runManyScripts,
    required this.runOneScript,
    bool runConcurrently = true,
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
        defaultsTo: runConcurrently,
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

  @override
  final PubspecLock pubspecLock;
  final PubspecYaml pubspecYaml;
  final Bindings bindings;
  @override
  final FindFile findFile;
  @override
  final Logger logger;
  @override
  final FileSystem fs;
  @override
  final ScriptsYaml scriptsYaml;
  final RunManyScripts runManyScripts;
  final RunOneScript runOneScript;

  ({Duration? dart, Duration? flutter})? get retryAfter => null;

  @override
  String get description => '$name dependencies for pubspec.yaml files';

  ExitCode onFinish(ExitCode exitCode) => exitCode;

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final result = await _run(args);

    return onFinish(result);
  }

  Future<Iterable<String>> pubspecs({required bool recursive}) async {
    return await pubspecYaml.all(recursive: recursive);
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
                sequentially: true,
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
                sequentially: true,
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
              sequentially: true,
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
