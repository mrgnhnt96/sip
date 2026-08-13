import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/analytics.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/variables.dart';
import 'package:sip_cli/src/domain/executables.dart';
import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:sip_cli/src/domain/scripts_json.dart';
import 'package:sip_cli/src/utils/json_output.dart';
import 'package:sip_cli/src/utils/script_locations_loader.dart';

const _usage = '''
Usage: sip list [query] [arguments]

List all scripts defined in scripts.yaml

Options:
  --help, -h  Print usage information
  --json      Print every script as JSON: its dotted key, aliases,
              description, raw and fully resolved commands, and where it is
              declared in scripts.yaml
  --no-resolve
              With --json, skip expanding references and variables
''';

/// The command to list all available scripts
class ListCommand {
  const ListCommand();

  Future<ExitCode> run([List<String> queries = const []]) async {
    if (args.get<bool>('help', defaultValue: false)) {
      logger.write(_usage);
      return ExitCode.success;
    }

    final asJson = args.get<bool>('json', defaultValue: false);

    await analytics.track('list', props: {'json': asJson});

    final query = switch (queries) {
      [] => null,
      _ => queries.join(' '),
    };

    final scriptConfig = ScriptsConfig.load();

    if (asJson) {
      return _json(scriptConfig, query);
    }

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

  ExitCode _json(ScriptsConfig config, String? query) {
    final resolve = args.getOrNull<bool>('resolve') ?? true;

    Iterable<Script>? only;
    if (query != null) {
      only = config.search(query).toList();

      if (only.isEmpty) {
        logger.err('No scripts found for query: $query');
        return ExitCode.noInput;
      }
    }

    final executables = Executables.load();

    final payload = scriptsConfigToJson(
      config,
      locations: loadScriptLocations(),
      executables: {
        'dart': executables.dart,
        'flutter': executables.flutter,
        ...executables.all,
      },
      variables: variables.retrieve(),
      resolve: resolve,
      only: only,
    );

    writeJson(payload);

    return ExitCode.success;
  }
}
