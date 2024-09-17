// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommandResult _$CommandResultFromJson(Map json) => CommandResult(
      exitCode: (json['exit_code'] as num).toInt(),
      output: json['output'] as String,
      error: json['error'] as String,
    );

Map<String, dynamic> _$CommandResultToJson(CommandResult instance) =>
    <String, dynamic>{
      'exit_code': instance.exitCode,
      'output': instance.output,
      'error': instance.error,
    };
