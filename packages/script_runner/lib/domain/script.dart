import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sip_script_runner/domain/script_env.dart';
import 'package:sip_script_runner/domain/scripts_config.dart';
import 'package:sip_script_runner/utils/constants.dart';
import 'package:sip_script_runner/utils/try_read_list_or_string.dart';

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
    required this.bail,
    required this.parents,
    required this.env,
  });

  const Script.defaults({
    required this.name,
    this.commands = const [],
    this.aliases = const {},
    this.scripts,
    this.description,
    this.bail = false,
    this.parents,
    this.env,
  });

  factory Script.fromJson(String name, dynamic json, {List<String>? parents}) {
    final possibleCommands = tryReadListOrString(json);

    if (possibleCommands != null) {
      return Script.defaults(
        name: name,
        commands: possibleCommands,
        parents: parents,
      );
    }

    return _$ScriptFromJson(
      {
        ...?json as Map?,
        Keys.name: name,
        if (parents != null) Keys.parents: parents,
      },
    );
  }

  @JsonKey(name: Keys.name)
  final String name;

  @JsonKey(readValue: _readCommand)
  final List<String> commands;

  @JsonKey(name: Keys.parents)
  final List<String>? parents;

  @JsonKey(
    name: Keys.aliases,
    readValue: _retrieveStrings,
  )
  final Set<String> aliases;

  @JsonKey(
    name: Keys.bail,
    readValue: _retrieveBool,
  )
  final bool bail;

  @JsonKey(name: Keys.description)
  final String? description;

  @JsonKey(name: Keys.env, readValue: _readEnv)
  final ScriptEnv? env;

  @JsonKey(readValue: _readScriptsConfig)
  final ScriptsConfig? scripts;

  Map<String, dynamic> toJson() => _$ScriptToJson(this);

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

    scripts?.listOut(
      buffer: buffer,
      prefix: '$prefix  ',
      wrapCallableKey: wrapCallableKey,
      wrapNonCallableKey: wrapNonCallableKey,
      wrapMeta: wrapMeta,
    );

    return buffer.toString();
  }

  @override
  List<Object?> get props => _$props;
}

// ignore: strict_raw_type
bool? _retrieveBool(Map json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  if (value == null && json.containsKey(key)) {
    return true;
  }

  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' => true,
      'yes' => true,
      'y' => true,
      _ => false,
    };
  }

  return null;
}

// ignore: strict_raw_type
List? _retrieveStrings(Map json, String key) {
  return tryReadListOrString(json[key]);
}

// ignore: strict_raw_type
Map? _readScriptsConfig(Map json, String key) {
  final parents = [...json[Keys.parents] as List<String>? ?? []];
  final name = json[Keys.name] as String;

  final mutableMap = {...json};

  final removeKeys = {...Keys.scriptParameters};
  // remove all other keys
  mutableMap.removeWhere(
    (key, _) => removeKeys.contains(key),
  );

  if (mutableMap.isEmpty) {
    return null;
  }

  parents.add(name);
  mutableMap[Keys.parents] = parents;

  return mutableMap;
}

// ignore: strict_raw_type
List<String>? _readCommand(Map json, String key) {
  return tryReadListOrString(json[key]) ??
      tryReadListOrString(json[Keys.command]);
}

// ignore: strict_raw_type
Map? _readEnv(Map json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  return switch (value) {
    String() => {'file': value},
    List() => {'files': value},
    Map() => value,
    _ => null,
  };
}
