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

    final executables = scriptsYaml.executables();

    variables[Vars.cwd] = cwd.path;
    for (final MapEntry(:key, :value) in (executables ?? {}).entries) {
      if (value is! String) continue;

      variables[key] = value;
    }

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
    EnvConfig? parentEnvConfig,
    OptionalFlags? flags,
  }) sync* {
    late final sipVariables = populate();
    Iterable<ResolveScript> resolve(
      String command,
      Script script,
    ) sync* {
      yield* replaceVariables(
        command,
        sipVariables: sipVariables,
        config: config,
        flags: flags,
        script: script,
        envConfigOfParent: parentEnvConfig,
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

    final envConfig = <EnvConfig>{
      ...envCommands,
    };

    final commands = <ResolveScript>[];
    for (final command in script.commands) {
      final resolved = resolve(
        command,
        script,
      ).toList();

      commands.addAll(resolved);
      envConfig.addAll([
        if (parentEnvConfig != null) parentEnvConfig,
        for (final e in resolved)
          for (final command in e.envConfig?.commands ?? <String>[])
            EnvConfig(
              commands: resolve(command, script)
                  .map((e) => e.command)
                  .whereType<String>(),
              files: e.envConfig?.files,
              workingDirectory: directory,
            ),
      ]);
    }

    yield ResolveScript(
      resolvedScripts: commands,
      envConfig: envConfig.combine(directory: directory),
      script: script,
      needsRunBeforeNext: false,
    );
  }

  Iterable<ResolveScript> replaceVariables(
    String command, {
    required Map<String, String?> sipVariables,
    required ScriptsConfig config,
    required Script script,
    EnvConfig? envConfigOfParent,
    OptionalFlags? flags,
  }) sync* {
    final matches = variablePattern.allMatches(command);

    if (matches.isEmpty) {
      yield ResolveScript.command(
        command: command,
        envConfig: [
          envConfigOfParent,
          script.envConfig(directory: directory),
        ].combine(directory: directory),
        script: script,
        needsRunBeforeNext: false,
      );

      return;
    }

    Iterable<ResolveScript> resolvedCommands = [
      ResolveScript.command(
        command: command,
        envConfig: null,
        script: script,
        needsRunBeforeNext: false,
      ),
    ];
    final resolvedEnvCommands = <EnvConfig?>{};

    final parentEnvConfig = script.envConfig(directory: directory);

    for (final match in matches) {
      final variable = match.group(1);
      final partToReplace = match.group(0)!;

      if (variable == null) {
        continue;
      }

      if (variable.startsWith(r'$')) {
        final scriptPath = variable.substring(1).split(':');

        final found = config.find(scriptPath);

        if (found == null) {
          throw Exception('Script path $variable is invalid');
        }

        final replacedScripts = replace(
          found,
          config,
          flags: flags,
          parentEnvConfig: parentEnvConfig,
        );

        for (final replaced in replacedScripts) {
          resolvedEnvCommands.add(replaced.envConfig);

          final commandsToCopy = [...resolvedCommands];

          final copied = List<ResolveScript>.generate(
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
            final copy = commandsToCopy[commandsToCopyIndex].copy()
              ..replaceCommandPart(partToReplace, command);

            return copy;
          });

          resolvedCommands = copied;
        }

        continue;
      }

      if (variable.startsWith('-')) {
        // flags are optional, so if not found, replace with empty string
        final flag = flags?[variable] ?? '';

        for (final command in resolvedCommands) {
          command.replaceCommandPart(partToReplace, flag);
        }

        continue;
      }

      final sipValue = sipVariables[variable];

      if (sipValue == null) {
        throw Exception('Variable $variable is not defined');
      }

      for (final command in resolvedCommands) {
        command.replaceCommandPart(partToReplace, sipValue);
      }
    }

    final commandsWithEnv = resolvedCommands
        .map(
          (e) => e.copy(
            envConfig: resolvedEnvCommands.combine(directory: directory),
          ),
        )
        .toList();

    if (script.commands.length == 1) {
      yield* commandsWithEnv;
      return;
    }

    final commandIndex = script.commands.indexOf(command);

    if (commandIndex == -1) {
      throw Exception('Command $command not found in script ${script.name}');
    }

    final hasConcurrency = script.commands
        .elementAt(commandIndex)
        .startsWith(Identifiers.concurrent);

    if (hasConcurrency) {
      yield* commandsWithEnv;
      return;
    }

    final commands = commandsWithEnv.toList();
    final last = commands.removeLast();

    yield* commands;
    yield last.copy(needsRunBeforeNext: true);
  }
}

class ResolveScript {
  ResolveScript({
    required this.resolvedScripts,
    required this.envConfig,
    required this.script,
    required this.needsRunBeforeNext,
  }) : originalCommand = null;

  ResolveScript._({
    required this.resolvedScripts,
    required this.envConfig,
    required this.script,
    required this.originalCommand,
    required this.needsRunBeforeNext,
    required String? replacedCommand,
  }) : _replacedCommand = replacedCommand;

  ResolveScript.command({
    required String command,
    required this.envConfig,
    required this.script,
    required this.needsRunBeforeNext,
  })  : resolvedScripts = const [],
        originalCommand = command;

  final Script script;
  final String? originalCommand;
  final Iterable<ResolveScript> resolvedScripts;
  final EnvConfig? envConfig;
  final bool needsRunBeforeNext;

  String? _replacedCommand;

  void replaceCommandPart(String part, String replacement) {
    _replacedCommand ??= command;
    _replacedCommand = _replacedCommand?.replaceAll(part, replacement);
  }

  ResolveScript copy({
    EnvConfig? envConfig,
    bool? needsRunBeforeNext,
  }) {
    return ResolveScript._(
      resolvedScripts: resolvedScripts,
      envConfig: envConfig ?? this.envConfig,
      script: script,
      originalCommand: originalCommand,
      replacedCommand: _replacedCommand,
      needsRunBeforeNext: needsRunBeforeNext ?? this.needsRunBeforeNext,
    );
  }

  Iterable<ResolveScript> get flatten => {
        if (command != null)
          this
        else if (resolvedScripts.isNotEmpty)
          ...resolvedScripts.expand((e) => e.flatten),
      };

  String? get command => _replacedCommand ?? originalCommand;
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
