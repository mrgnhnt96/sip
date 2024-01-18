// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'script.dart';

// **************************************************************************
// AutoequalGenerator
// **************************************************************************

extension _$ScriptAutoequal on Script {
  List<Object?> get _$props => [
        commands,
        aliases,
        description,
        scripts,
      ];
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Script _$ScriptFromJson(Map json) => Script.defaults(
      commands: (_readCommand(json, 'commands') as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      aliases: (json['(aliases)'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          {},
      scripts: _readScriptsConfig(json, 'scripts') == null
          ? null
          : ScriptsConfig.fromJson(_readScriptsConfig(json, 'scripts') as Map),
      description: json['(description)'] as String?,
    );

Map<String, dynamic> _$ScriptToJson(Script instance) => <String, dynamic>{
      'commands': instance.commands,
      '(aliases)': instance.aliases.toList(),
      '(description)': instance.description,
      'scripts': instance.scripts?.toJson(),
    };
