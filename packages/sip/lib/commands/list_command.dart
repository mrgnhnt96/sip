import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

/// The command to list all available scripts
class ListCommand extends Command<ExitCode> {
  ListCommand({
    required this.scriptsYaml,
    required this.logger,
  });

  final ScriptsYaml scriptsYaml;
  final Logger logger;

  @override
  String get description => 'List all scripts defined in scripts.yaml';

  @override
  String get name => 'list';

  @override
  List<String> get aliases => ['ls'];

  @override
  Future<ExitCode> run() async {
    final content = scriptsYaml.scripts();
    if (content == null) {
      logger.err('No ${ScriptsYaml.fileName} file found');
      return ExitCode.noInput;
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    logger
      ..write('\n')
      ..info(
        scriptConfig.listOut(
          wrapCallableKey: (s) => lightGreen.wrap(s) ?? s,
          wrapNonCallableKey: (s) => cyan.wrap(s) ?? s,
          wrapMeta: (s) => lightBlue.wrap(s) ?? s,
        ),
      );

    return ExitCode.success;
  }
}
