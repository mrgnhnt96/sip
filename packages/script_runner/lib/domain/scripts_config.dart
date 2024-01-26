import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:autoequal/autoequal.dart';
// ignore_for_file: must_be_immutable
import 'package:sip_script_runner/domain/script.dart';
import 'package:sip_script_runner/utils/constants.dart';

part 'scripts_config.g.dart';

@JsonSerializable(createFactory: false)
class ScriptsConfig extends Equatable {
  ScriptsConfig({
    required this.scripts,
  })  : assert(
          !scripts.containsKey(Keys.command),
          'The key "${Keys.command}" cannot exist in the config',
        ),
        assert(
          !scripts.containsKey(Keys.description),
          'The key "${Keys.description}" cannot exist in the config',
        ),
        assert(
          !scripts.containsKey(Keys.aliases),
          'The key "${Keys.aliases}" cannot exist in the config',
        );

  factory ScriptsConfig.fromJson(Map json) {
    final scripts = <String, Script>{};

    final allowedKeys = RegExp(r'^[a-z0-9_.\-]+$');

    for (final entry in json.entries) {
      final key = entry.key.trim();
      if (key.contains(' ')) {
        print(
          'The script name "${key}" contains spaces, '
          'which is not allowed.',
        );
        continue;
      }

      if (!allowedKeys.hasMatch(key) && !Keys.values.contains(key)) {
        print(
          'The script name "${key}" uses forbidden characters, allowed: ${allowedKeys.pattern}',
        );
        continue;
      }

      scripts[key] = Script.fromJson(
        key,
        entry.value,
      );
    }

    return ScriptsConfig(scripts: scripts);
  }

  @JsonKey(defaultValue: {})
  final Map<String, Script> scripts;

  @ignore
  bool _hasSetupAliases = false;
  @ignore
  late Map<String, Script> _aliases;
  @ignore
  late Map<String, List<String>> _deactivatedAliases;

  void _mapAliases() {
    final aliases = <String, Script>{};
    final deactivatedAliases = <String, List<String>>{};

    for (final MapEntry(key: name, value: script) in scripts.entries) {
      if (script.aliases.isEmpty) continue;

      for (final alias in script.aliases) {
        if (aliases.containsKey(alias)) {
          (deactivatedAliases[alias] ??= []).add(name);
        } else {
          aliases[alias] = script;
        }
      }
    }

    _aliases = aliases;
    _deactivatedAliases = deactivatedAliases;
    _hasSetupAliases = true;
  }

  Script? find(List<String> keys) {
    Script? _find(String key) {
      if (scripts.containsKey(key)) {
        return scripts[key];
      }

      if (!_hasSetupAliases) {
        _mapAliases();
      }

      if (_aliases.containsKey(key)) {
        return _aliases[key];
      }

      if (_deactivatedAliases.containsKey(key)) {
        print(
          'The alias "$key" is deactivated '
          'because duplicates have been found in:'
          '\n${_deactivatedAliases[key]!.map((e) => e).join('\n')}',
        );

        return null;
      }
      return null;
    }

    Script? script = _find(keys.first);
    if (script == null) return null;
    if (keys.length == 1) return script;

    for (var i = 1; i < keys.length; i++) {
      script = script?.scripts?.find(keys.sublist(i));
      if (script == null) return null;
    }

    return script;
  }

  Map<String, dynamic> toJson() => _$ScriptsConfigToJson(this);

  String listOut({
    StringBuffer? buffer,
    String? prefix,
    String Function(String)? wrapKey,
    String Function(String)? wrapMeta,
  }) {
    buffer ??= StringBuffer();
    wrapKey ??= (key) => key;
    wrapMeta ??= (meta) => meta;
    if (prefix == null) {
      buffer.writeln('scripts.yaml:');
    }

    prefix ??= '   ';

    final keys = scripts.keys.toList();
    bool isLast(String key) => keys.last == key;

    for (final MapEntry(:key, value: script) in scripts.entries) {
      final entry = isLast(key) ? '└──' : '├──';
      buffer.writeln('$prefix$entry${wrapKey(key)}');
      final sub = isLast(key) ? '   ' : '│  ';
      script.listOut(
        buffer: buffer,
        prefix: prefix + sub,
        wrapKey: wrapKey,
        wrapMeta: wrapMeta,
      );
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => _$props;
}
