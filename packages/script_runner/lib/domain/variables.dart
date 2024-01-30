import 'package:path/path.dart' as path;
import 'package:sip_script_runner/domain/optional_flags.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:sip_script_runner/utils/constants.dart';

/// The variables that can be used in the scripts
class Variables {
  const Variables({
    required this.pubspecYaml,
    required this.scriptsYaml,
    required this.cwd,
  });

  final PubspecYaml pubspecYaml;
  final ScriptsYaml scriptsYaml;
  final CWD cwd;

  Map<String, String?> populate() {
    final variables = <String, String?>{};

    final projectRoot = pubspecYaml.nearest();
    variables[Vars.projectRoot] =
        projectRoot == null ? null : path.dirname(projectRoot);

    final scriptsRoot = scriptsYaml.nearest();
    variables[Vars.scriptsRoot] =
        scriptsRoot == null ? null : path.dirname(scriptsRoot);

    variables[Vars.cwd] = cwd.path;

    return variables;
  }

  List<String> replace(
    Script script,
    ScriptsConfig config, {
    OptionalFlags? flags,
  }) {
    final commands = <String>[];

    final variablePattern = RegExp(r'(?:{)(\$?-{0,2}\w+(?::\w+)*)(?:})');

    late final Map<String, String?> sipVariables = populate();

    for (final command in script.commands) {
      final matches = variablePattern.allMatches(command);

      if (matches.isEmpty) {
        commands.add(command);
        continue;
      }

      Iterable<String> resolvedCommands = [command];

      for (final match in matches) {
        final variable = match.group(1);

        if (variable == null) {
          continue;
        }

        if (variable.startsWith('\$')) {
          final scriptPath = variable.substring(1).split(':');

          final found = config.find(scriptPath);

          if (found == null) {
            throw Exception('Script path $variable is invalid');
          }

          final resolved = replace(found, config);

          final commandsToCopy = [...resolvedCommands];

          resolvedCommands =
              List.generate(resolvedCommands.length * resolved.length, (index) {
            final commandIndex = index % resolved.length;
            final command = resolved[commandIndex];

            final commandsToCopyIndex = index ~/ resolved.length;
            final commandsToCopyCommand = commandsToCopy[commandsToCopyIndex];

            return commandsToCopyCommand.replaceAll(match.group(0)!, command);
          });

          continue;
        }

        if (variable.startsWith('-')) {
          // flags are optional, so if not found, replace with empty string
          final flag = flags?[variable] ?? '';

          resolvedCommands =
              resolvedCommands.map((e) => e.replaceAll(match.group(0)!, flag));

          continue;
        }

        final sipValue = sipVariables[variable];

        if (sipValue == null) {
          throw Exception('Variable $variable is not defined');
        }

        resolvedCommands = resolvedCommands
            .map((e) => e.replaceAll(match.group(0)!, sipValue));
      }

      commands.addAll(resolvedCommands);
    }

    return commands.map((e) => e.trim()).toList();
  }
}
