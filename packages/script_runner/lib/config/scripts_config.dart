import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:autoequal/autoequal.dart';
// ignore_for_file: must_be_immutable
import 'package:sip_script_runner/config/script.dart';

part 'scripts_config.g.dart';

@JsonSerializable(createFactory: false)
class ScriptsConfig extends Equatable {
  ScriptsConfig({
    required this.scripts,
  });

  factory ScriptsConfig.fromJson(Map json) {
    final scripts = <String, Script>{};
    for (final entry in json.entries) {
      if (entry.key.contains(' ')) {
        print(
          'The script name "${entry.key}" contains spaces, '
          'which is not allowed.',
        );
        continue;
      }

      scripts[entry.key] = Script.fromJson(entry.value);
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

  @override
  List<Object?> get props => _$props;
}