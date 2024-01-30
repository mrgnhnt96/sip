import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sip_script_runner/domain/scripts_config.dart';
import 'package:sip_script_runner/utils/constants.dart';

part 'script.g.dart';

/// Parses an entry from the `scripts.yaml` file
@JsonSerializable(constructor: 'defaults')
class Script extends Equatable {
  const Script({
    required this.name,
    required this.commands,
    required this.aliases,
    required this.description,
    required this.scripts,
  });

  const Script.defaults({
    required this.name,
    this.commands = const [],
    this.aliases = const {},
    this.scripts,
    this.description,
  });

  factory Script.fromJson(String name, dynamic json) {
    final possibleCommands = _tryReadListOrString(json);

    if (possibleCommands != null) {
      return Script.defaults(name: name, commands: possibleCommands);
    }

    return _$ScriptFromJson(
      {
        ...json,
        'name': name,
      },
    );
  }

  final String name;

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

  String listOut({
    StringBuffer? buffer,
    String? prefix,
    String Function(String)? wrapKey,
    String Function(String)? wrapMeta,
  }) {
    buffer ??= StringBuffer();
    wrapKey ??= (key) => key;
    wrapMeta ??= (meta) => meta;
    prefix ??= '';

    if (description != null) {
      buffer.writeln('${prefix}${wrapMeta(Keys.description)}: $description');
    }

    if (aliases.isNotEmpty) {
      buffer
          .writeln('${prefix}${wrapMeta(Keys.aliases)}: ${aliases.join(', ')}');
    }

    scripts?.listOut(
      buffer: buffer,
      prefix: '$prefix  ',
      wrapKey: wrapKey,
      wrapMeta: wrapMeta,
    );

    return buffer.toString();
  }

  @override
  List<Object?> get props => _$props;
}

List? _retrieveStrings(Map json, String key) {
  return _tryReadListOrString(json[key]);
}

Map? _readScriptsConfig(Map json, String key) {
  final mutableMap = {...json};

  // remove all other keys
  mutableMap.removeWhere(
    (key, _) => {
      Keys.command,
      Keys.aliases,
      Keys.description,
      'name',
    }.contains(key),
  );

  if (mutableMap.isEmpty) {
    return null;
  }

  return mutableMap;
}

List<String>? _readCommand(Map json, String key) {
  return _tryReadListOrString(json[key]) ??
      _tryReadListOrString(json[Keys.command]);
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
