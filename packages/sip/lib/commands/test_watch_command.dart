import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/commands/test_command/tester_mixin.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/domain/bindings.dart';
import 'package:sip_script_runner/domain/pubspec_lock.dart';
import 'package:sip_script_runner/domain/pubspec_yaml.dart';

class TestWatchCommand extends Command<ExitCode> with TesterMixin {
  TestWatchCommand({
    required this.bindings,
    required this.findFile,
    required this.fs,
    required this.logger,
    required this.pubspecLock,
    required this.pubspecYaml,
  });

  @override
  String get name => 'watch';

  @override
  String get description => 'Run tests in watch mode.';

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
  Future<ExitCode> run([List<String>? args]) async {
    final argResults = args != null ? argParser.parse(args) : super.argResults!;

    return ExitCode.success;
  }
}
