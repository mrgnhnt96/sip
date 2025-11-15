import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/analytics.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/deps/script_runner.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/utils/package.dart';

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

    final isRecursive = args.get<bool>(
      'recursive',
      abbr: 'r',
      defaultValue: false,
    );
    final isConcurrent = args.get<bool>('concurrent', defaultValue: true);
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

    final packages = pubspecs.map(Package.new);

    await analytics.track(
      'clean',
      props: {
        'is_recursive': isRecursive,
        'is_concurrent': isConcurrent,
        'erase_pubspec_lock': erasePubspecLock,
        'pubspecs_count': pubspecs.length,
        'flutter_packages_count': packages.where((e) => e.isFlutter).length,
        'dart_packages_count': packages.where((e) => e.isDart).length,
      },
    );

    final baseRemoveCommands = [
      'rm -rf .dart_tool',
      'rm -rf build',
      if (erasePubspecLock) 'rm -f pubspec.lock',
    ];

    final commands = <ScriptToRun>[];
    for (final pkg in packages) {
      if (pkg.isPartOfWorkspace) {
        logger.detail('Skipping workspace package: ${pkg.relativePath}');
        continue;
      }

      final removeCommands = [...baseRemoveCommands];
      if (pkg.isFlutter) {
        removeCommands.add('flutter clean');
      }

      var label = darkGray.wrap('Cleaning (')!;
      label += cyan.wrap(pkg.tool)!;
      label += darkGray.wrap(') in ')!;
      label += yellow.wrap(pkg.relativePath)!;

      final command = ScriptToRun(
        removeCommands.join(' && '),
        workingDirectory: pkg.path,
        label: label,
        runInParallel: isConcurrent,
      );

      commands.add(command);
    }

    logger.detail('Running ${commands.length} commands');
    final result = await scriptRunner.run(
      commands.toList(),
      bail: false,
      disableConcurrency: !isConcurrent,
    );

    return result.exitCodeReason;
  }
}
