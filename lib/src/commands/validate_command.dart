import 'package:mason_logger/mason_logger.dart';
import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/deps/analytics.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/deps/variables.dart';
import 'package:sip_cli/src/domain/diagnostic.dart';
import 'package:sip_cli/src/domain/script_validator.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:sip_cli/src/domain/scripts_json.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/utils/json_output.dart';

const _usage = '''
Usage: sip validate [arguments]

Check scripts.yaml for problems without running anything

Reports unresolvable references, malformed substitutions, circular
references, invalid script names, duplicate aliases and settings that do not
mean what they look like -- each against the line it was written on.

Options:
  --help              Print usage information
  --json              Print the diagnostics as JSON
  --fatal-warnings    Exit non-zero for warnings as well as errors
''';

/// The `validate` command.
///
/// `scripts.yaml` mistakes used to surface only when a script ran, as a shell
/// error a long way from its cause -- or not at all, in the cases where sip
/// silently does something other than what the file appears to say. This
/// checks the file directly and points at the line.
class ValidateCommand {
  const ValidateCommand();

  Future<ExitCode> run() async {
    if (args.get<bool>('help', defaultValue: false)) {
      logger.write(_usage);
      return ExitCode.success;
    }

    final asJson = args.get<bool>('json', defaultValue: false);
    final fatalWarnings = args.get<bool>('fatal-warnings', defaultValue: false);

    await analytics.track('validate', props: {'json': asJson});

    final file = scriptsYaml.nearest();
    final content = switch (file) {
      null => null,
      final file => scriptsYaml.retrieveContent(file),
    };

    if (file == null || content == null) {
      const message = 'No ${ScriptsYaml.fileName} file found';

      if (asJson) {
        writeJson({
          'version': scriptsJsonVersion,
          'scriptsYaml': null,
          'ok': false,
          'errors': 1,
          'warnings': 0,
          'diagnostics': [
            const Diagnostic.error(
              code: 'no-scripts-yaml',
              message: 'No scripts.yaml file found.',
            ).toJson(),
          ],
        });
      } else {
        logger.err(message);
      }

      return ExitCode.noInput;
    }

    // Loading the config and the variables logs its own unlocated complaints
    // about the very things this command is about to report properly. Silence
    // them so every problem is reported once, with a location.
    final (config, knownVariables) = await runScoped(
      () async => (ScriptsConfig.load(), variables.retrieve().keys.toSet()),
      values: {loggerProvider.overrideWith(() => Logger(level: Level.quiet))},
    );

    final result = validateScripts(
      content: content,
      file: file,
      config: config,
      knownVariables: knownVariables,
    );

    if (asJson) {
      writeJson({
        'version': scriptsJsonVersion,
        'scriptsYaml': file,
        'ok': !result.hasErrors,
        'errors': result.errors.length,
        'warnings': result.warnings.length,
        'diagnostics': [
          for (final diagnostic in result.diagnostics) diagnostic.toJson(),
        ],
      });
    } else {
      _report(result, file);
    }

    if (result.hasErrors) return ExitCode.config;
    if (fatalWarnings && result.hasWarnings) return ExitCode.config;

    return ExitCode.success;
  }

  void _report(ValidationResult result, String file) {
    if (result.isClean) {
      logger.info('${green.wrap('✓')} $file has no problems');
      return;
    }

    for (final diagnostic in result.diagnostics) {
      final line = diagnostic.format();

      // Errors on stderr, warnings on stderr too: stdout stays free for
      // --json, and a caller redirecting it gets nothing but the payload.
      switch (diagnostic.severity) {
        case Severity.error:
          logger.err(line);
        case Severity.warning:
          logger.warn(line, tag: '');
      }

      if (diagnostic.help case final help?) {
        logger.warn('  $help', tag: '');
      }
    }

    final errors = result.errors.length;
    final warnings = result.warnings.length;

    logger.info(
      '${errors == 1 ? '1 error' : '$errors errors'}, '
      '${warnings == 1 ? '1 warning' : '$warnings warnings'}',
    );
  }
}
