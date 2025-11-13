import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/find_file.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';

const _usage = '''
Usage: sip test clean

Clean the test optimized files.
''';

class TestCleanCommand with TesterMixin {
  TestCleanCommand();

  Future<ExitCode> run() async {
    if (args.get<bool>('help', defaultValue: false)) {
      logger.write(_usage);
      return ExitCode.success;
    }

    final pubspecs = await pubspecYaml.all(recursive: true);

    if (pubspecs.isEmpty) {
      logger.err('No pubspec.yaml files found');
      return ExitCode.unavailable;
    }

    final testDirsResult = getTestDirs(
      pubspecs,
      isFlutterOnly: false,
      isDartOnly: false,
    );

    // exit code is not null
    if (testDirsResult case (_, final ExitCode exitCode)) {
      return exitCode;
    }
    final (testDirs, _) = testDirsResult.$1!;

    final optimized = <String>[];
    for (final dir in testDirs) {
      final file = findFile.fileWithin(TesterMixin.optimizedTestBasename, dir);

      if (file == null) continue;

      optimized.add(file);
    }

    cleanUpOptimizedFiles(optimized);

    return ExitCode.success;
  }
}
