// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'script.dart';

// **************************************************************************
// AutoequalGenerator
// **************************************************************************

extension _$ScriptAutoequal on Script {
  List<Object?> get _$props => [
    name,
    commands,
    parents,
    aliases,
    bail,
    description,
    env,
    scripts,
  ];
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Script _$ScriptFromJson(Map json) => Script.defaults(
  name: json['__(name)__'] as String,
  commands:
      (_readCommand(json, 'commands') as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  aliases:
      (_retrieveStrings(json, '(aliases)') as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
  scripts: _readScriptsConfig(json, 'scripts') == null
      ? null
      : ScriptsConfig.fromJson(_readScriptsConfig(json, 'scripts') as Map),
  description: json['(description)'] as String?,
  bail: _retrieveBool(json, '(bail)') as bool? ?? false,
  parents: (json['__(parents)__'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  env: _readEnv(json, '(env)') == null
      ? null
      : ScriptEnv.fromJson(
          Map<String, dynamic>.from(_readEnv(json, '(env)') as Map),
        ),
);

Map<String, dynamic> _$ScriptToJson(Script instance) => <String, dynamic>{
  '__(name)__': instance.name,
  'commands': instance.commands,
  '__(parents)__': instance.parents,
  '(aliases)': instance.aliases.toList(),
  '(bail)': instance.bail,
  '(description)': instance.description,
  '(env)': instance.env?.toJson(),
  'scripts': instance.scripts?.toJson(),
};
