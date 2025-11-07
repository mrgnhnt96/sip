import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/utils/exit_code.dart';

const _usage = '''
Usage: sip list [query] [arguments]

List all scripts defined in scripts.yaml

Options:
  --help, -h  Print usage information
''';

/// The command to list all available scripts
class ListCommand {
  const ListCommand();

  Future<ExitCode> run([List<String> queries = const []]) async {
    if (args.get<bool>('help', defaultValue: false)) {
      logger.write(_usage);
      return ExitCode.success;
    }

    final query = switch (queries) {
      [] => null,
      _ => queries.join(' '),
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
