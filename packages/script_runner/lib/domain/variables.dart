import 'package:path/path.dart' as path;
import 'package:sip_console/domain/domain.dart';
import 'package:sip_script_runner/setup.dart';
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

    final definedVariables = scriptsYaml.variables();
    for (final MapEntry(:key, :value) in (definedVariables ?? {}).entries) {
      if (value is! String) {
        getIt<SipConsole>().w('Variable $key is not a string');
        continue;
      }

      if (Vars.values.contains(key)) {
        getIt<SipConsole>().w('Variable $key is a reserved keyword');
        continue;
      }

      variables[key] = value;
    }

    for (final MapEntry(:key, value: variable) in {...variables.entries}) {
      if (variable == null) {
        continue;
      }

      final matches = variablePattern.allMatches(variable);

      if (matches.isEmpty) {
        continue;
      }

      final keyToCheckForCircular = {key};

      String? resolve(RegExpMatch match, String variable) {
        final referencedVariable = match.group(1);
        final wholeMatch = match.group(0)!;

        if (referencedVariable == null) {
          getIt<SipConsole>().w('Variable $referencedVariable is not defined');
          return null;
        }

        if (referencedVariable.startsWith('\$')) {
          getIt<SipConsole>()
              .w('Variable $key is referencing a script, this is forbidden');
          return null;
        }

        if (referencedVariable.startsWith('-')) {
          return variable;
        }

        keyToCheckForCircular.add(referencedVariable);

        final referencedValue = variables[referencedVariable];

        if (referencedValue == null) {
          getIt<SipConsole>().w('Variable $referencedVariable is not defined');
          return null;
        }

        var almostResolved = variable.replaceAll(wholeMatch, referencedValue);

        if (variablePattern.hasMatch(almostResolved)) {
          for (final match in variablePattern.allMatches(almostResolved)) {
            // check for circular references
            if (keyToCheckForCircular.contains(match.group(1))) {
              getIt<SipConsole>()
                  .w('Circular reference detected for variable $key');
              return null;
            }

            final partialResolved = resolve(match, almostResolved);

            if (partialResolved == null) {
              return null;
            }

            almostResolved =
                almostResolved.replaceAll(match.group(0)!, partialResolved);
          }
        }

        return almostResolved;
      }

      for (final match in matches) {
        final resolved = resolve(match, variable);

        variables[key] = resolved;
      }
    }

    return variables;
  }

  static final variablePattern =
      RegExp(r'(?:{)(\$?-{0,2}[\w-_]+(?::[\w-_]+)*)(?:})');

  List<String> replace(
    Script script,
    ScriptsConfig config, {
    OptionalFlags? flags,
  }) {
    final commands = <String>[];

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

          final resolved = replace(found, config, flags: flags);

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
