import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

/// A command that runs `pub *`.
abstract class APubCommand extends Command<ExitCode> {
  APubCommand({
    PubspecLock pubspecLock = const PubspecLockImpl(),
    PubspecYaml pubspecYaml = const PubspecYamlImpl(),
    Bindings bindings = const BindingsImpl(),
    FindFile findFile = const FindFile(),
  })  : _pubspecLock = pubspecLock,
        _pubspecYaml = pubspecYaml,
        _bindings = bindings,
        _findFile = findFile {
    argParser.addFlag(
      'recursive',
      abbr: 'r',
      defaultsTo: false,
      negatable: false,
      help: 'Run command recursively in all subdirectories.',
    );

    argParser.addFlag(
      'concurrent',
      aliases: ['parallel'],
      abbr: 'c',
      defaultsTo: true,
      negatable: true,
      help: 'Run command concurrently in all subdirectories.',
    );

    argParser.addFlag(
      'bail',
      abbr: 'b',
      defaultsTo: false,
      negatable: false,
      help: 'Stop running commands if one fails.',
    );
  }

  List<String> get pubFlags => [];

  final PubspecLock _pubspecLock;
  final PubspecYaml _pubspecYaml;
  final Bindings _bindings;
  final FindFile _findFile;

  @override
  String get description => '$name dependencies for pubspec.yaml files';

  @override
  Future<ExitCode> run() async {
    final recursive = argResults!['recursive'] as bool;

    final allPubspecs = <String>{};

    final pubspecPath = _pubspecYaml.nearest();
    if (pubspecPath != null) {
      allPubspecs.add(pubspecPath);
    }

    if (recursive) {
      final children = await _pubspecYaml.children();

      allPubspecs.addAll(children);
    }

    if (allPubspecs.isEmpty) {
      getIt<SipConsole>().e('No pubspec.yaml files found.');
      return ExitCode.unavailable;
    }

    final commands = <CommandToRun>[];
    for (final pubspec in allPubspecs) {
      final tool = DetermineFlutterOrDart(
        pubspecYaml: pubspec,
        pubspecLock: _pubspecLock,
        findFile: _findFile,
      ).tool();

      final project = path.dirname(pubspec);

      final relativeDir = path.relative(
        project,
        from: getIt<FileSystem>().currentDirectory.path,
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
        bindings: _bindings,
      );

      getIt<SipConsole>()
          .l('Running ${lightCyan.wrap('pub $name ${pubFlags.join(' ')}')}');

      final exitCodes = await runMany.run();

      exitCodes.printErrors(commands);

      return exitCodes.exitCode;
    } else {
      for (final command in commands) {
        getIt<SipConsole>().l('\nRunning ${lightCyan.wrap(command.command)}');

        final exitCode = await RunOneScript(
          command: command,
          bindings: _bindings,
        ).run();

        if (exitCode != ExitCode.success && argResults!['bail'] == true) {
          exitCode.printError(command);
          return exitCode;
        }
      }

      return ExitCode.success;
    }
  }
}
