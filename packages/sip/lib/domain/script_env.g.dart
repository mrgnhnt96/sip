// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'script_env.dart';

// **************************************************************************
// AutoequalGenerator
// **************************************************************************

extension _$ScriptEnvAutoequal on ScriptEnv {
  List<Object?> get _$props => [
        files,
        command,
      ];
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScriptEnv _$ScriptEnvFromJson(Map json) => ScriptEnv(
      files: (_readFiles(json, 'files') as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      command: (_readScript(json, 'command') as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ScriptEnvToJson(ScriptEnv instance) => <String, dynamic>{
      'files': instance.files,
      'command': instance.command,
    };
