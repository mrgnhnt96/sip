import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/domain/bindings.dart';
import 'package:sip_script_runner/domain/pubspec_lock.dart';
import 'package:sip_script_runner/domain/pubspec_yaml.dart';

class TestCleanCommand extends Command<ExitCode> with TesterMixin {
  TestCleanCommand({
    required this.bindings,
    required this.findFile,
    required this.fs,
    required this.logger,
    required this.pubspecLock,
    required this.pubspecYaml,
  });

  @override
  String get name => 'clean';

  @override
  String get description => 'Clean the test optimized files.';

  @override
  final Bindings bindings;

  @override
  final FindFile findFile;

  @override
  final FileSystem fs;

  @override
  final Logger logger;

  @override
  final PubspecLock pubspecLock;

  @override
  final PubspecYaml pubspecYaml;

  @override
  Future<ExitCode> run() async {
    final pubspecs = await this.pubspecs(isRecursive: true);

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
    if (testDirsResult.$2 case final ExitCode exitCode) {
      return exitCode;
    }
    final (testDirs, _) = testDirsResult.$1!;

    final optimized = <String>[];
    for (final dir in testDirs) {
      final file = findFile.fileWithin(TesterMixin.optimizedTestBasename, dir);

      if (file == null) continue;

      optimized.add(file);
    }

    final done = logger.progress('Cleaning up optimized test files');

    cleanUp(optimized);

    done.complete('Optimized test files cleaned!');

    return ExitCode.success;
  }
}
