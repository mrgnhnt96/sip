import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sip_script_runner/config/scripts_config.dart';
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
    final possibleCommands = _tryReadCommand(json);

    if (possibleCommands != null) {
      return Script.defaults(commands: possibleCommands);
    }

    return _$ScriptFromJson(json);
  }

  @JsonKey(readValue: _readCommand)
  final List<String> commands;

  @JsonKey(
    defaultValue: {},
    name: Keys.aliases,
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
  final possibleCommands = _tryReadCommand(json[key]);

  if (possibleCommands != null) {
    return possibleCommands;
  }

  final possibleCommand = _tryReadCommand(json[Keys.scripts]);

  if (possibleCommand != null) {
    return possibleCommand;
  }

  return null;
}

List<String>? _tryReadCommand(dynamic json) {
  if (json is String) {
    return [json];
  } else if (json is List) {
    return json.cast<String>();
  }

  return null;
}
