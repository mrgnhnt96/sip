import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sip_script_runner/domain/scripts_config.dart';
import 'package:sip_script_runner/utils/constants.dart';

part 'script.g.dart';

@JsonSerializable(constructor: 'defaults')
class Script extends Equatable {
  const Script({
    required this.commands,
    required this.aliases,
    required this.description,
    required this.scripts,
  });

  const Script.defaults({
    this.commands = const [],
    this.aliases = const {},
    this.scripts,
    this.description,
  });

  factory Script.fromJson(dynamic json) {
    final possibleCommands = _tryReadListOrString(json);

    if (possibleCommands != null) {
      return Script.defaults(commands: possibleCommands);
    }

    return _$ScriptFromJson(json);
  }

  @JsonKey(readValue: _readCommand)
  final List<String> commands;

  @JsonKey(
    name: Keys.aliases,
    readValue: _retrieveStrings,
  )
  final Set<String> aliases;
  @JsonKey(name: Keys.description)
  final String? description;

  @JsonKey(readValue: _readScriptsConfig)
  final ScriptsConfig? scripts;

  Map<String, dynamic> toJson() => _$ScriptToJson(this);

  @override
  List<Object?> get props => _$props;
}

List? _retrieveStrings(Map json, String key) {
  final data = json[key];

  if (data == null) return null;

  if (data is! List) return null;

  return _tryReadListOrString(data);
}

Map? _readScriptsConfig(Map json, String key) {
  final mutableMap = {...json};

  // remove all other keys
  mutableMap.removeWhere(
    (key, _) => {
      Keys.scripts,
      Keys.aliases,
      Keys.description,
    }.contains(key),
  );

  if (mutableMap.isEmpty) {
    return null;
  }

  return mutableMap;
}

List<String>? _readCommand(Map json, String key) {
  return _tryReadListOrString(json[key]) ??
      _tryReadListOrString(json[Keys.scripts]);
}

List<String>? _tryReadListOrString(dynamic json) {
  if (json is String) {
    final trimmed = json.trim();
    if (trimmed.isEmpty) return null;

    return [trimmed];
  } else if (json is List) {
    final list = <String>[];
    for (final e in json) {
      if (e is! String) continue;

      final trimmed = e.trim();
      if (trimmed.isEmpty) continue;

      list.add(trimmed);
    }

    return list;
  }

  return null;
}
