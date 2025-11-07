// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'script_env.dart';

// **************************************************************************
// AutoequalGenerator
// **************************************************************************

extension _$ScriptEnvAutoequal on ScriptEnv {
  List<Object?> get _$props => [files, commands, vars];
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScriptEnv _$ScriptEnvFromJson(Map json) => ScriptEnv(
  files:
      (_readFiles(json, 'files') as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  commands:
      (_readScript(json, 'commands') as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  vars:
      (_readVariables(json, 'vars') as Map?)?.map(
        (k, e) => MapEntry(k as String, e as String),
      ) ??
      const {},
);

Map<String, dynamic> _$ScriptEnvToJson(ScriptEnv instance) => <String, dynamic>{
  'files': instance.files,
  'commands': instance.commands,
  'vars': instance.vars,
};
