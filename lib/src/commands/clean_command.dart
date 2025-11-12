import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/deps/script_runner.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/utils/determine_flutter_or_dart.dart';

const _usage = '''
Usage: sip clean [options]

Removes the .dart_tool and build directories,
runs `flutter clean` in flutter packages

Options:
  --pubspec-lock, -l      Whether to remove the pubspec.lock file.
  --[no-]concurrent, -c   Cleans packages concurrently
  --recursive, -r         Cleans packages in subdirectories
''';

class CleanCommand {
  const CleanCommand();

  Future<ExitCode> run() async {
    if (args.get<bool>('help', defaultValue: false)) {
      logger.write(_usage);
      return ExitCode.success;
    }

    final isRecursive = args.get<bool>('recursive', defaultValue: false);
    final isConcurrent = args.get<bool>('concurrent', defaultValue: false);
    final erasePubspecLock = args.get<bool>(
      'pubspec-lock',
      defaultValue: false,
    );

    final pubspecs = await pubspecYaml.all(recursive: isRecursive);

    logger.detail('Found ${pubspecs.length} pubspec.yaml files');
    for (final pubspec in pubspecs) {
      logger.detail(' - $pubspec');
    }

    if (pubspecs.isEmpty) {
      logger.err('No pubspec.yaml files found');
      return ExitCode.usage;
    }

    final packages = pubspecs.map(DetermineFlutterOrDart.new);

    final baseRemoveCommands = [
      'rm -rf .dart_tool',
      'rm -rf build',
      if (erasePubspecLock) 'rm -f pubspec.lock',
    ];

    final commands = <ScriptToRun>[];
    for (final package in packages) {
      final removeCommands = [...baseRemoveCommands];
      if (package.isFlutter) {
        removeCommands.add('flutter clean');
      }

      var label = darkGray.wrap('Cleaning (')!;
      label += cyan.wrap(package.tool())!;
      label += darkGray.wrap(') in ')!;
      label += yellow.wrap(
        package.directory(fromDirectory: fs.currentDirectory.path),
      )!;

      final command = ScriptToRun(
        removeCommands.join(' && '),
        workingDirectory: package.directory(),
        label: label,
      );

      commands.add(command);
    }

    if (isConcurrent) {
      final results = await scriptRunner.run(commands.toList(), bail: false);

      return results.exitCodeReason;
    } else {
      final result = await scriptRunner.run(
        commands.toList(),
        disableConcurrency: true,
        bail: false,
      );

      return result.exitCodeReason;
    }
  }
}
