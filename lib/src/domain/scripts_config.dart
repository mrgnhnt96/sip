// ignore_for_file: must_be_immutable

import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/utils/constants.dart';

/// The `scripts.yaml` file.
///
/// Also nested scripts.
class ScriptsConfig {
  ScriptsConfig(this.scripts);

  // ignore: strict_raw_type
  factory ScriptsConfig.load() {
    final json = scriptsYaml.scripts();
    if (json == null) {
      logger.err('No ${ScriptsYaml.fileName} file found');

      return ScriptsConfig(const {});
    }

    final scripts = <String, Script>{};

    final allowedKeys = RegExp(
      r'^_?([a-z][a-z0-9_.\-]*)?(?<=[a-z0-9_])$',
      caseSensitive: false,
    );

    for (final MapEntry(key: rawKey, :value) in json.entries) {
      final key = rawKey.trim();
      if (key.contains(' ')) {
        logger.err(
          'The script name "$key" contains spaces, '
          'which is not allowed.',
        );
        continue;
      }

      if (!allowedKeys.hasMatch(key) && !Keys.scriptParameters.contains(key)) {
        logger.err(
          'The script name "$key" uses forbidden characters, allowed: '
          '${allowedKeys.pattern} (case insensitive)',
        );
        continue;
      }

      scripts[key] = Script.fromJson(key, value);
    }

    return ScriptsConfig(scripts);
  }

  final Map<String, Script> scripts;

  Script? _parent;
  Script? get parent => _parent;
  set parent(Script? value) {
    if (_parent != null && _parent != value) {
      logger.err('The scripts config already has a parent');
      return;
    }

    _parent = value;
  }

  Script? find(List<String> keys) {
    Script? find(String key, Map<String, Script> scripts) {
      if (scripts[key] case final script?) {
        return script;
      }

      final aliases = <String, Script>{};
      final deactivatedAliases = <String, List<Script>>{};

      for (final script in scripts.values) {
        for (final alias in script.aliases) {
          if (aliases.containsKey(alias)) {
            (deactivatedAliases[alias] ??= []).add(script);
            continue;
          }

          aliases[alias] = script;
        }
      }

      if (aliases[key] case final script?) {
        return script;
      }

      if (deactivatedAliases[key] case final badScripts?) {
        final id = badScripts
            .map((e) => '${e.name} (${e.keys.join(' ')})')
            .join('\n');

        logger.err(
          'The alias "$key" is deactivated '
          'because duplicates have been found in:'
          '\n$id',
        );

        return null;
      }

      return null;
    }

    Script? script;
    for (final key in keys) {
      final children = switch (key == keys.first) {
        true => scripts,
        false => script?.scripts,
      };

      if (children == null) {
        break;
      }

      if (find(key, children) case final s?) {
        script = s;
      }
    }

    if (script == null) {
      return null;
    }

    if (script.name != keys.last) {
      if (!script.aliases.contains(keys.last)) {
        return null;
      }
    }

    return script;
  }

  String listOut({
    StringBuffer? buffer,
    String Function(String)? wrapCallableKey,
    String Function(String)? wrapNonCallableKey,
    String Function(String)? wrapMeta,
  }) {
    buffer ??= StringBuffer();
    wrapCallableKey ??= (key) => key;
    wrapNonCallableKey ??= (key) => key;
    wrapMeta ??= (meta) => meta;
    buffer.writeln('scripts.yaml:');

    const prefix = '   ';

    final keys = scripts.keys.where((e) => !e.startsWith('_'));
    bool isLast(String key) => keys.last == key;

    for (final MapEntry(:key, value: script) in scripts.entries) {
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

    return buffer.toString();
  }

  Iterable<Script> search(String query) sync* {
    final results = this.query(query);

    for (final (hasMatch, script) in results) {
      if (!hasMatch) continue;

      yield script;
    }
  }

  Iterable<(bool, Script)> query(String query) sync* {
    for (final script in scripts.values) {
      yield* script.query(query);
    }
  }
}
