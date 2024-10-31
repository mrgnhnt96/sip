import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/cwd.dart';
import 'package:sip_cli/domain/env_config.dart';
import 'package:sip_cli/domain/optional_flags.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/script.dart';
import 'package:sip_cli/domain/scripts_config.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/utils/constants.dart';
import 'package:sip_cli/utils/working_directory.dart';

/// The variables that can be used in the scripts
class Variables with WorkingDirectory {
  Variables({
    required this.pubspecYaml,
    required this.scriptsYaml,
    required this.cwd,
  });

  final PubspecYaml pubspecYaml;
  @override
  final ScriptsYaml scriptsYaml;
  @override
  final CWD cwd;

  Logger get logger => Logger();

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
        logger.warn('Variable $key is not a string');
        continue;
      }

      if (Vars.values.contains(key)) {
        logger.warn('Variable $key is a reserved keyword');
        continue;
      }

      variables[key] = value;
    }

    for (final MapEntry(:key, value: variable) in {...variables.entries}) {
      if (variable == null) {
        continue;
      }

      final matches = variablePattern.allMatches('$variable');

      if (matches.isEmpty) {
        continue;
      }

      final keyToCheckForCircular = {key};

      String? resolve(RegExpMatch match, String variable) {
        final referencedVariable = match.group(1);
        final wholeMatch = match.group(0)!;

        if (referencedVariable == null) {
          logger.warn('Variable $referencedVariable is not defined');
          return null;
        }

        if (referencedVariable.startsWith(r'$')) {
          logger.warn(
            'Variable $key is referencing a script, this is forbidden',
          );
          return null;
        }

        if (referencedVariable.startsWith('-')) {
          return variable;
        }

        keyToCheckForCircular.add(referencedVariable);

        final referencedValue = variables[referencedVariable];

        if (referencedValue == null) {
          logger.warn('Variable $referencedVariable is not defined');
          return null;
        }

        var almostResolved = variable.replaceAll(wholeMatch, referencedValue);

        if (variablePattern.hasMatch(almostResolved)) {
          for (final match in variablePattern.allMatches(almostResolved)) {
            // check for circular references
            if (keyToCheckForCircular.contains(match.group(1))) {
              logger.warn('Circular reference detected for variable $key');
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
        final resolved = resolve(match, '$variable');

        variables['$key'] = resolved;
      }
    }

    return variables;
  }

  static final variablePattern =
      // what if we added a new pattern to match :{...}?
      // instead of {$...} which requires to wrap the input with quotes
      RegExp(r'(?:{)(\$?-{0,2}[\w-_]+(?::[\w-_]+)*)(?:})');

  Iterable<ResolveScript> replace(
    Script script,
    ScriptsConfig config, {
    OptionalFlags? flags,
  }) sync* {
    late final sipVariables = populate();
    Iterable<ResolveScript> resolve(String command, Script script) sync* {
      yield* replaceVariables(
        command,
        sipVariables: sipVariables,
        config: config,
        flags: flags,
        script: script,
      );
    }

    final envCommands = <EnvConfig>{
      if (script.env?.commands case final commands)
        for (final command in commands ?? <String>[])
          EnvConfig(
            commands: resolve(command, script)
                .map((e) => e.command)
                .whereType<String>(),
            files: script.env?.files,
            workingDirectory: directory,
          ),
    };

    final envConfig = {
      ...envCommands,
    };

    final commands = <ResolveScript>[];
    for (final command in script.commands) {
      final resolved = resolve(command, script);

      commands.addAll(resolved);
      envConfig.addAll([
        for (final e in resolved)
          if (e.envConfig case final config?) config,
      ]);
    }

    yield ResolveScript(
      resolvedScripts: commands,
      envConfig: envConfig.combine(directory: directory),
      script: script,
    );
  }

  Iterable<ResolveScript> replaceVariables(
    String command, {
    required Map<String, String?> sipVariables,
    required ScriptsConfig config,
    required Script script,
    OptionalFlags? flags,
  }) sync* {
    final matches = variablePattern.allMatches(command);

    if (matches.isEmpty) {
      yield ResolveScript.command(
        command: command,
        envConfig: script.envConfig(directory: directory),
        script: script,
      );

      return;
    }

    Iterable<String> resolvedCommands = [command];
    final resolvedEnvCommands = <EnvConfig>{};

    for (final match in matches) {
      final variable = match.group(1);

      if (variable == null) {
        continue;
      }

      if (variable.startsWith(r'$')) {
        final scriptPath = variable.substring(1).split(':');

        final found = config.find(scriptPath);

        if (found == null) {
          throw Exception('Script path $variable is invalid');
        }

        for (final replaced in replace(found, config, flags: flags)) {
          if (replaced.envConfig case final config?) {
            resolvedEnvCommands.add(config);
          }

          final commandsToCopy = [...resolvedCommands];

          final copied = List.generate(
              resolvedCommands.length * replaced.resolvedScripts.length,
              (index) {
            final commandIndex = index % replaced.resolvedScripts.length;
            final command =
                replaced.resolvedScripts.elementAt(commandIndex).command;

            if (command == null) {
              throw Exception('Command is null');
            }

            final commandsToCopyIndex =
                index ~/ replaced.resolvedScripts.length;
            final commandsToCopyCommand = commandsToCopy[commandsToCopyIndex];

            return commandsToCopyCommand.replaceAll(match.group(0)!, command);
          });

          resolvedCommands = copied;
        }

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

      resolvedCommands = resolvedCommands.map(
        (e) => e.replaceAll(match.group(0)!, sipValue),
      );
    }

    for (final command in resolvedCommands) {
      yield ResolveScript.command(
        command: command,
        envConfig: resolvedEnvCommands.combine(directory: directory),
        script: script,
      );
    }
  }
}

class ResolveScript {
  const ResolveScript({
    required this.resolvedScripts,
    required this.envConfig,
    required this.script,
  }) : command = null;

  const ResolveScript.command({
    required String this.command,
    required this.envConfig,
    required this.script,
  }) : resolvedScripts = const [];

  final Script script;
  final String? command;
  final Iterable<ResolveScript> resolvedScripts;
  final EnvConfig? envConfig;
}

extension _ScriptX on Script {
  EnvConfig? envConfig({required String directory}) {
    final env = this.env;
    if (env == null) return null;

    if (env.commands.isEmpty && env.files.isEmpty) return null;

    return EnvConfig(
      commands: {...env.commands},
      files: {...env.files},
      workingDirectory: directory,
    );
  }
}
