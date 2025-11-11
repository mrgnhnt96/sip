// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/variables.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/resolved_script.dart';
import 'package:sip_cli/src/domain/script_env.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:sip_cli/src/domain/variables.dart';
import 'package:sip_cli/src/utils/constants.dart';

class Script {
  Script({
    required this.name,
    this.commands = const [],
    this.aliases = const {},
    this.bail = false,
    this.scripts,
    this.description,
    this.env,
  }) {
    if (scripts case final scripts?) {
      for (final script in scripts.values) {
        script.parent = this;
      }
    }
  }

  Script._({
    required this.name,
    required this.commands,
    required this.aliases,
    required this.bail,
    required this.scripts,
    required this.description,
    required this.env,
  }) {
    if (scripts case final scripts?) {
      for (final script in scripts.values) {
        script.parent = this;
      }
    }
  }

  factory Script.fromJson(String name, dynamic json) {
    final possibleCommands = switch (json) {
      final String command => [command],
      final List<dynamic> commands => [
        for (final command in commands)
          if (command case final String command)
            if (command.trim() case final String command
                when command.isNotEmpty)
              command,
      ],
      _ => null,
    };

    if (possibleCommands != null) {
      return Script(name: name, commands: possibleCommands);
    }

    if (json is! Map<String, dynamic>) {
      logger.err('The script "$name" is not a valid script');
      return Script(name: name);
    }

    final commands = switch (json[Keys.command]) {
      final String command => [command],
      final List<dynamic> commands => [
        for (final command in commands)
          if (command case final String command)
            if (command.trim() case final command when command.isNotEmpty)
              command,
      ],
      _ => <String>[],
    };

    final aliases = switch (json[Keys.aliases]) {
      final String alias => {alias},
      final List<dynamic> aliases => {
        for (final alias in aliases)
          if (alias case final String alias)
            if (alias.trim() case final alias when alias.isNotEmpty) alias,
      },
      _ => <String>{},
    };

    final bail = switch (json[Keys.bail]) {
      final bool bail => bail,
      'true' || 'yes' || 'y' => true,
      _ => false,
    };

    final description = switch (json[Keys.description]) {
      final String description => description,
      _ => null,
    };

    final env = switch (json[Keys.env]) {
      final Map<dynamic, dynamic> env => ScriptEnv.fromJson(env),
      _ => null,
    };

    final mutableJson = {...json};
    for (final key in Keys.scriptParameters) {
      mutableJson.remove(key);
    }

    final scripts = switch (mutableJson) {
      final Map<String, dynamic> json when json.isNotEmpty => {
        for (final MapEntry(:key, :value) in json.entries)
          if (_keyIsValid(key)) key: Script.fromJson(key, value),
      },
      _ => null,
    };

    return Script._(
      name: name,
      commands: commands,
      aliases: aliases,
      bail: bail,
      description: description,
      env: env,
      scripts: scripts,
    );
  }

  final String name;
  final List<String> commands;
  final Set<String> aliases;
  final bool bail;
  final String? description;
  final ScriptEnv? env;
  final Map<String, Script>? scripts;

  bool get isPrivate => name.startsWith('_');
  bool get isPublic => !isPrivate;
  Iterable<String> get keys => [...parents.map((e) => e.name), name];
  String get path => parents.map((e) => e.name).join('.');

  Script? _parent;
  Script? get parent => _parent;
  set parent(Script? value) {
    if (_parent != null && _parent != value) {
      logger.err('The script "$name" already has a parent');
      return;
    }

    _parent = value;
  }

  List<Script> get parents {
    Iterable<Script> retrieve() sync* {
      var parent = this.parent;
      while (parent != null) {
        yield parent;
        parent = parent.parent;
      }
    }

    return retrieve().toList();
  }

  String listOut({
    StringBuffer? buffer,
    String? prefix,
    String Function(String)? wrapCallableKey,
    String Function(String)? wrapNonCallableKey,
    String Function(String)? wrapMeta,
  }) {
    buffer ??= StringBuffer();

    if (name.startsWith('_')) return buffer.toString();

    wrapCallableKey ??= (key) => key;
    wrapNonCallableKey ??= (key) => key;
    wrapMeta ??= (meta) => meta;
    prefix ??= '';

    if (description != null) {
      buffer.writeln('$prefix${wrapMeta(Keys.description)}: $description');
    }

    if (aliases.isNotEmpty) {
      buffer.writeln('$prefix${wrapMeta(Keys.aliases)}: ${aliases.join(', ')}');
    }

    final publicKeys = scripts?.keys.where((e) => !e.startsWith('_')) ?? [];
    bool isLast(String key) => publicKeys.last == key;

    if (scripts?.entries case final entries?) {
      for (final MapEntry(:key, value: script) in entries) {
        if (key.startsWith('_')) continue;

        final wrapper = script.commands.isEmpty
            ? wrapNonCallableKey
            : wrapCallableKey;

        final entry = isLast(key) ? '└──' : '├──';
        buffer.writeln('$prefix$entry${wrapper(key)}');
        final sub = isLast(key) ? '   ' : '│  ';
        script.listOut(
          buffer: buffer,
          prefix: prefix + sub,
          wrapCallableKey: wrapCallableKey,
          wrapNonCallableKey: wrapNonCallableKey,
          wrapMeta: wrapMeta,
        );
      }
    }

    return buffer.toString();
  }

  Iterable<(bool, Script)> query(String query) sync* {
    if (_matchesQuery(this, query)) {
      yield (true, this);
    }

    final scripts = this.scripts?.values ?? [];

    for (final script in scripts) {
      final hasMatch = _matchesQuery(script, query);
      yield (hasMatch, script);

      if (hasMatch) continue;

      yield* script.query(query);
    }
  }

  bool _matchesQuery(Script script, String query) {
    if (script.isPrivate) return false;
    if (script.name.contains(query)) return true;
    if (script.aliases.contains(query)) return true;
    if (script.description case final String description
        when description.contains(query)) {
      return true;
    }

    return false;
  }

  String printDetails() {
    if (isPrivate) return '';

    final buffer = StringBuffer();

    final name = cyan.wrap(this.name);

    final keys = yellow.wrap(this.keys.join(' '));
    buffer.writeln('$name: $keys');

    if (description case final String description) {
      final descriptionTitle = darkGray.wrap('description');
      buffer.writeln('  $descriptionTitle: $description');
    }

    if (scripts?.values case final scripts?) {
      for (final script in scripts) {
        final lines = script.printDetails().split('\n');

        for (final line in lines) {
          final trimmed = line.trimRight();
          if (trimmed.isEmpty) continue;

          buffer.writeln('  $trimmed');
        }
      }
    }

    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (other is! Script) return false;
    return other.name == name &&
        other.commands == commands &&
        other.aliases == aliases &&
        other.bail == bail &&
        other.description == description &&
        other.env == env &&
        other.scripts == scripts;
  }

  @override
  int get hashCode => Object.hashAll([
    name,
    commands,
    aliases,
    bail,
    description,
    env,
    scripts,
  ]);

  (ResolvedScript?, ExitCode?) resolve({
    Args flags = const Args(),
    ResolvedScript? parent,
    ScriptsConfig? scriptsConfig,
  }) {
    final sipVariables = variables.retrieve();
    final config = scriptsConfig ?? ScriptsConfig.load();

    final resolved = ResolvedScript(this, parent: parent);

    for (final part in resolved.parts) {
      final matches = [
        ...Variables.variablePattern.allMatches(part.part),
        ...Variables.oldVariablePattern.allMatches(part.part),
      ];

      if (matches.isEmpty) {
        if (matches.isEmpty) {
          continue;
        }
      }

      for (final match in matches) {
        final variable = match.group(1);
        final replacee = match.group(0);
        if (variable == null || replacee == null) continue;

        if (sipVariables[variable] case final value?) {
          part.part = part.part.replaceAll(replacee, value);
          continue;
        }

        if (variable.startsWith('-')) {
          final cleanVariable = variable.replaceAll(RegExp('^-+'), '');
          // flags are optional, so if not found, replace with empty string
          final flagArg = switch (flags[cleanVariable]) {
            null => null,
            final value => '$value',
          };

          part.part = part.part.replaceAll(replacee, switch (flagArg) {
            null => '',
            'true' => '--$cleanVariable',
            'false' => '--no-$cleanVariable',
            _ => '--$cleanVariable $flagArg',
          });
          resolved.addFlag(cleanVariable, flagArg ?? '');
          continue;
        }

        final variableParts = switch ((
          variable.contains('.'),
          variable.contains(':'),
        )) {
          (true, _) => variable.split('.'),
          (_, true) => variable.split(':'),
          _ => [variable],
        };
        if (variableParts case [final first, ...]) {
          if (first.startsWith(r'$')) {
            variableParts[0] = first.substring(1);
          }
        }

        // find script
        final reference = config.find(variableParts);

        if (reference == null) {
          final location = keys.join(' ');

          logger.err('Script $variable not found. (Referened by $location)');
          return (null, ExitCode.config);
        }

        if (parent?.scriptsUsed.contains(reference) case true) {
          final parentLocation = resolved.parent?.script.keys.join('.');
          final location = resolved.script.keys.join('.');
          throw Exception(
            'Circular reference detected: $replacee\n'
            '"$location" referenced from "$parentLocation"',
          );
        }

        resolved.addScriptUsed(reference);

        final (resolvedSubScript, exitCode) = reference.resolve(
          flags: flags,
          parent: resolved,
          scriptsConfig: config,
        );
        if (exitCode != null) {
          return (null, exitCode);
        }

        if (resolvedSubScript == null) {
          return (null, ExitCode.config);
        }

        part.replacees[replacee] = resolvedSubScript;
      }
    }

    return (resolved, null);
  }

  @override
  String toString() {
    return commands.join(' | ');
  }
}

final _allowedKeys = RegExp(
  r'^_?([a-z][a-z0-9_.\-]*)?(?<=[a-z0-9_])$',
  caseSensitive: false,
);

bool _keyIsValid(String rawKey) {
  final key = rawKey.trim();
  if (key.contains(' ')) {
    logger.err(
      'The script name "$key" contains spaces, '
      'which is not allowed.',
    );
    return false;
  }

  if (!_allowedKeys.hasMatch(key) && !Keys.scriptParameters.contains(key)) {
    logger.err(
      'The script name "$key" uses forbidden characters, allowed: '
      '${_allowedKeys.pattern} (case insensitive)',
    );
    return false;
  }

  return true;
}
