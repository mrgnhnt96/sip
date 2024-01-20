import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:sip/domain/find_file.dart';
import 'package:sip/domain/pubspec_lock_impl.dart';
import 'package:sip/domain/pubspec_yaml_impl.dart';
import 'package:sip/domain/run_many.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/domain/pubspec_lock.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class APubGetCommand extends Command<ExitCode> {
  APubGetCommand({
    PubspecLock pubspecLock = const PubspecLockImpl(),
    PubspecYaml pubspecYaml = const PubspecYamlImpl(),
  })  : _pubspecLock = pubspecLock,
        _pubspecYaml = pubspecYaml {
    argParser.addFlag(
      'recursive',
      abbr: 'r',
      defaultsTo: false,
      help: 'Run command recursively in all subdirectories.',
    );

    argParser.addMultiOption(
      'in',
      abbr: 'i',
      help: 'Run command in the specified directories.',
    );
  }

  final PubspecLock _pubspecLock;
  final PubspecYaml _pubspecYaml;

  @override
  String get description => '$name dependencies for pubspec.yaml files';

  @override
  String get name => 'get';

  @override
  Future<ExitCode> run() async {
    final recursive = argResults!['recursive'] as bool;

    final allPubspecs = [];

    final pubspecPath = _pubspecYaml.nearest();
    if (pubspecPath != null) {
      allPubspecs.add(pubspecPath);
    }

    if (recursive) {
      final inPaths = argResults!['in'] as List<String>;

      final children = await _pubspecYaml.children(inPaths);

      allPubspecs.addAll(children);
    } else if (allPubspecs.isEmpty) {
      getIt<SipConsole>().e('No pubspec.yaml file found.');
      return ExitCode.osFile;
    }

    final commands = <CommandToRun>[];
    for (final pubspec in allPubspecs) {
      final directory = path.dirname(pubspec);

      final nestedLock = _pubspecLock.findIn(directory);

      var command = 'dart pub $name';

      if (nestedLock != null) {
        final contents = FindFile().retrieveContent(nestedLock);

        if (contents != null && contents.contains(RegExp('flutter'))) {
          command = 'flutter pub $name';
        }
      } else {
        final contents = FindFile().retrieveContent(pubspec);

        if (contents != null && contents.contains('flutter')) {
          command = 'flutter pub $name';
        }
      }

      final relativeDir = path.relative(
        directory,
        from: getIt<FileSystem>().currentDirectory.path,
      );

      commands.add(
        CommandToRun(
          command: command,
          directory: directory,
          label:
              'Running "${lightCyan.wrap(command)}" in ${lightYellow.wrap('./$relativeDir')}',
        ),
      );
    }

    final runMany = RunMany(
      commands: commands,
    );

    return runMany.run();
  }
}
