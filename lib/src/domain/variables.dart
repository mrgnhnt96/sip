import 'package:path/path.dart' as path;
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/pubspec_yaml.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/utils/constants.dart';
import 'package:sip_cli/src/utils/working_directory.dart';

/// The variables that can be used in the scripts
class Variables with WorkingDirectory {
  Variables();

  Map<String, String?> retrieve() {
    final variables = <String, String?>{};

    final projectRoot = pubspecYaml.nearest();
    variables[Vars.projectRoot] = projectRoot == null
        ? null
        : path.dirname(projectRoot);

    final scriptsRoot = scriptsYaml.nearest();
    variables[Vars.scriptsRoot] = scriptsRoot == null
        ? null
        : path.dirname(scriptsRoot);

    final executables = scriptsYaml.executables();

    variables[Vars.cwd] = fs.currentDirectory.path;
    for (final MapEntry(:key, :value) in (executables ?? {}).entries) {
      if (value case final String value) {
        variables[key] = value;
      } else {
        logger.warn(
          'Executable $key is must be a string, '
          'got ${value.runtimeType} ($value)',
        );
      }
    }

    final definedVariables = scriptsYaml.variables();
    for (final MapEntry(:key, :value) in (definedVariables ?? {}).entries) {
      if (value case final String value) {
        if (Vars.values.contains(key)) {
          logger.warn('Variable $key is a reserved keyword');
          continue;
        }

        variables[key] = value;
      } else {
        logger.warn(
          'Variable $key is must be a string, '
          'got ${value.runtimeType} ($value)',
        );
      }
    }

    return variables;
  }

  // Matches ${{ some.value }} or ${{ --some-flag }}
  static final variablePattern = RegExp(
    r'\${{ ?(-{0,2}[\w-_]+(?:\.[\w-_]+)*) ?}}',
  );

  // Matches {$some.value} or {--some-flag}
  static final oldVariablePattern =
      // what if we added a new pattern to match :{...}?
      // instead of {$...} which requires to wrap the input with quotes
      RegExp(r'(?:{)(\$?-{0,2}[\w-_]+(?::[\w-_]+)*)(?:})');
}
