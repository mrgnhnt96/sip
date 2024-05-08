import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/exit_code_extensions.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class CleanCommand extends Command<ExitCode> {
  CleanCommand({
    required this.pubspecYaml,
    required this.pubspecLock,
    required this.findFile,
    required this.bindings,
    required this.logger,
    required this.cwd,
  }) {
    argParser
      ..addFlag(
        'pubspec-lock',
        help: 'Whether to remove the pubspec.lock file.',
        aliases: ['lock', 'locks', 'pubspec-locks'],
      )
      ..addFlag(
        'concurrent',
        abbr: 'c',
        help: 'Cleans packages concurrently',
        defaultsTo: true,
      )
      ..addFlag(
        'recursive',
        abbr: 'r',
        help: 'Cleans packages in subdirectories',
      );
  }

  @override
  String get description => 'Removes the .dart_tool and build directories, '
      'runs `flutter clean` in flutter packages';

  @override
  String get name => 'clean';

  final PubspecYaml pubspecYaml;
  final PubspecLock pubspecLock;
  final FindFile findFile;
  final Logger logger;
  final Bindings bindings;
  final CWD cwd;

  @override
  Future<ExitCode> run([List<String>? args]) async {
    final argResults = args != null ? argParser.parse(args) : super.argResults!;

    final isRecursive = argResults['recursive'] as bool? ?? false;
    final isConcurrent = argResults['concurrent'] as bool? ?? false;
    final erasePubspecLock = argResults['pubspec-lock'] as bool? ?? false;

    final pubspecs = await pubspecYaml.all(recursive: isRecursive);

    final packages = pubspecs.map(
      (e) => DetermineFlutterOrDart(
        pubspecYaml: e,
        pubspecLock: pubspecLock,
        findFile: findFile,
      ),
    );

    final baseRemoveCommands = [
      'rm -rf .dart_tool',
      'rm -rf build',
      if (erasePubspecLock) 'rm -f pubspec.lock',
    ];

    final commands = <CommandToRun>[];
    for (final package in packages) {
      final removeCommands = [...baseRemoveCommands];
      if (package.isFlutter) {
        removeCommands.add('flutter clean');
      }

      var label = darkGray.wrap('Cleaning (')!;
      label += cyan.wrap(package.tool())!;
      label += darkGray.wrap(') in ')!;
      label += yellow.wrap(package.directory(fromDirectory: cwd.path))!;

      final command = CommandToRun(
        command: removeCommands.join(' && '),
        workingDirectory: package.directory(),
        runConcurrently: isConcurrent,
        label: label,
      );

      commands.add(command);
    }

    ExitCode result;

    if (isConcurrent) {
      final runner = RunManyScripts(
        commands: commands,
        bindings: bindings,
        logger: logger,
      );

      final results = await runner.run(bail: false);

      results.printErrors(commands, logger);

      result = results.exitCode(logger);
    } else {
      result = ExitCode.success;

      for (final command in commands) {
        final runner = RunOneScript(
          command: command,
          bindings: bindings,
          logger: logger,
          showOutput: true,
        );

        final exitCode = await runner.run();

        exitCode.printError(command, logger);

        if (exitCode != ExitCode.success) {
          result = exitCode;
        }
      }
    }

    return result;
  }
}
