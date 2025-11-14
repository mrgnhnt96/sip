import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/utils/package.dart';

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

    final pkgs = pubspecs.map(Package.new);

    for (final pkg in pkgs) {
      pkg.deleteOptimizedTestFile();
    }

    return ExitCode.success;
  }
}
