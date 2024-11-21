import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/domain/scripts_config.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/utils/exit_code.dart';

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
  String get invocation {
    final invocation = super.invocation;

    final first = invocation.split(' [arguments]').first;

    return '$first [query] [arguments]';
  }

  @override
  Future<ExitCode> run() async {
    final query = switch (argResults?.rest) {
      [final String query, ...] => query,
      final Iterable<String> all when all.isNotEmpty => all.join(' '),
      _ => null,
    };

    final content = scriptsYaml.scripts();
    if (content == null) {
      logger.err('No ${ScriptsYaml.fileName} file found');
      return ExitCode.noInput;
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    if (query != null) {
      final result = scriptConfig.search(query);

      if (result.isEmpty) {
        logger.err('No scripts found for query: $query');
        return ExitCode.noInput;
      }

      logger
        ..detail('Found ${result.length} scripts for query: $query')
        ..write('\n');

      for (final script in result) {
        final details = script.printDetails().trim();
        if (details.isEmpty) continue;

        logger.info(details);
      }
    } else {
      logger
        ..write('\n')
        ..info(
          scriptConfig.listOut(
            wrapCallableKey: (s) => lightGreen.wrap(s) ?? s,
            wrapNonCallableKey: (s) => cyan.wrap(s) ?? s,
            wrapMeta: (s) => lightBlue.wrap(s) ?? s,
          ),
        );
    }

    return ExitCode.success;
  }
}
