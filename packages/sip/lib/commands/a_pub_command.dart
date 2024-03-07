// ignore_for_file: cascade_invocations

import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

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
    argParser.addFlag(
      'recursive',
      abbr: 'r',
      negatable: false,
      help: 'Run command recursively in all subdirectories.',
    );

    argParser.addFlag(
      'concurrent',
      aliases: ['parallel'],
      abbr: 'c',
      defaultsTo: true,
      help: 'Run command concurrently in all subdirectories.',
    );

    argParser.addFlag(
      'bail',
      abbr: 'b',
      negatable: false,
      help: 'Stop running commands if one fails.',
    );
  }

  List<String> get pubFlags => [];

  final PubspecLock pubspecLock;
  final PubspecYaml pubspecYaml;
  final Bindings bindings;
  final FindFile findFile;
  final Logger logger;
  final FileSystem fs;

  @override
  String get description => '$name dependencies for pubspec.yaml files';

  @override
  Future<ExitCode> run() async {
    final recursive = argResults!['recursive'] as bool;

    final allPubspecs = <String>{};

    final pubspecPath = pubspecYaml.nearest();
    if (pubspecPath != null) {
      allPubspecs.add(pubspecPath);
    }

    if (recursive) {
      final children = await pubspecYaml.children();

      allPubspecs.addAll(children);
    }

    if (allPubspecs.isEmpty) {
      logger.err('No pubspec.yaml files found.');
      return ExitCode.unavailable;
    }

    final commands = <CommandToRun>[];
    for (final pubspec in allPubspecs) {
      final tool = DetermineFlutterOrDart(
        pubspecYaml: pubspec,
        pubspecLock: pubspecLock,
        findFile: findFile,
      ).tool();

      final project = path.dirname(pubspec);

      final relativeDir = path.relative(
        project,
        from: fs.currentDirectory.path,
      );

      final padding = max('flutter'.length, tool.length) - tool.length;
      var toolString = '($tool)';
      toolString = darkGray.wrap(toolString) ?? toolString;
      toolString = toolString.padRight(padding + toolString.length);

      var pathString = './$relativeDir';
      pathString = lightYellow.wrap(pathString) ?? pathString;

      final label = '$toolString $pathString';

      commands.add(
        CommandToRun(
          command: '$tool pub $name ${pubFlags.join(' ')}',
          workingDirectory: project,
          label: label,
          keys: null,
        ),
      );
    }

    if (argResults!['concurrent'] == true) {
      final runMany = RunManyScripts(
        commands: commands,
        bindings: bindings,
        logger: logger,
      );

      logger
          .info('Running ${lightCyan.wrap('pub $name ${pubFlags.join(' ')}')}');

      final exitCodes = await runMany.run();

      exitCodes.printErrors(commands, logger);

      return exitCodes.exitCode(logger);
    } else {
      for (final command in commands) {
        logger.info('\nRunning ${lightCyan.wrap(command.command)}');

        final exitCode = await RunOneScript(
          command: command,
          bindings: bindings,
          logger: logger,
          showOutput: true,
        ).run();

        if (exitCode != ExitCode.success && argResults!['bail'] == true) {
          exitCode.printError(command, logger);
          return exitCode;
        }
      }

      return ExitCode.success;
    }
  }
}
