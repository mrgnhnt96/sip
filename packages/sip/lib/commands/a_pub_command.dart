import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip/domain/command_to_run.dart';
import 'package:sip/domain/find_file.dart';
import 'package:sip/domain/pubspec_lock_impl.dart';
import 'package:sip/domain/pubspec_yaml_impl.dart';
import 'package:sip/domain/run_many_scripts.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip/utils/exit_code_extensions.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/domain/pubspec_lock.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

abstract class APubGetCommand extends Command<ExitCode> {
  APubGetCommand({
    PubspecLock pubspecLock = const PubspecLockImpl(),
    PubspecYaml pubspecYaml = const PubspecYamlImpl(),
    Bindings bindings = const BindingsImpl(),
  })  : _pubspecLock = pubspecLock,
        _pubspecYaml = pubspecYaml,
        _bindings = bindings {
    argParser.addFlag(
      'recursive',
      abbr: 'r',
      defaultsTo: false,
      help: 'Run command recursively in all subdirectories.',
    );
  }

  List<String> get pubFlags => [];

  final PubspecLock _pubspecLock;
  final PubspecYaml _pubspecYaml;
  final Bindings _bindings;

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
    } else if (allPubspecs.isEmpty) {
      getIt<SipConsole>().e('No pubspec.yaml file found.');
      return ExitCode.osFile;
    }

    final commands = <CommandToRun>[];
    for (final pubspec in allPubspecs) {
      final directory = path.dirname(pubspec);

      final nestedLock = _pubspecLock.findIn(directory);

      var tool = 'dart';

      if (nestedLock != null) {
        final contents = FindFile().retrieveContent(nestedLock);

        if (contents != null && contents.contains(RegExp('flutter'))) {
          tool = 'flutter';
        }
      } else {
        final contents = FindFile().retrieveContent(pubspec);

        if (contents != null && contents.contains('flutter')) {
          tool = 'flutter';
        }
      }

      final relativeDir = path.relative(
        directory,
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
          workingDirectory: directory,
          label: label,
        ),
      );
    }

    final runMany = RunManyScripts(
      commands: commands,
      bindings: _bindings,
    );

    getIt<SipConsole>()
        .l('Running ${lightCyan.wrap('pub $name ${pubFlags.join(' ')}')}');

    final exitCodes = await runMany.run();

    exitCodes.printErrors(commands);

    return exitCodes.exitCode;
  }
}
