// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'script_env.dart';

// **************************************************************************
// AutoequalGenerator
// **************************************************************************

extension _$ScriptEnvAutoequal on ScriptEnv {
  List<Object?> get _$props => [
        file,
        command,
      ];
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScriptEnv _$ScriptEnvFromJson(Map json) => ScriptEnv(
      file: json['file'] as String?,
      command: (_readScript(json, 'command') as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ScriptEnvToJson(ScriptEnv instance) => <String, dynamic>{
      'file': instance.file,
      'command': instance.command,
    };
