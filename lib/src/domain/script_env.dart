import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sip_cli/src/utils/try_read_list_or_string.dart';

part 'script_env.g.dart';

@JsonSerializable()
class ScriptEnv extends Equatable {
  const ScriptEnv({
    this.files = const [],
    this.commands = const [],
    this.vars = const {},
  });

  factory ScriptEnv.fromJson(Map<String, dynamic> json) {
    return _$ScriptEnvFromJson(json);
  }

  /// the file to source when running the script
  @JsonKey(readValue: _readFiles)
  final List<String> files;

  /// The script to run to create the environment
  @JsonKey(readValue: _readScript)
  final List<String> commands;

  /// The environment variables to set when running the script
  @JsonKey(readValue: _readVariables)
  final Map<String, String> vars;

  Map<String, dynamic> toJson() => _$ScriptEnvToJson(this);

  @override
  List<Object?> get props => _$props;
}

// ignore: strict_raw_type
List? _readFiles(Map json, String key) {
  return tryReadListOrString(json[key] ?? json['file']);
}

// ignore: strict_raw_type
List<String> _readScript(Map json, String key) {
  return tryReadListOrString(json[key] ?? json['command']) ?? [];
}

// ignore: strict_raw_type
Map<String, dynamic> _readVariables(Map json, String key) {
  final map = json[key] ?? json['variables'];

  final result = <String, dynamic>{};

  // ignore: strict_raw_type
  if (map case final Map map) {
    for (final MapEntry(:key, :value) in map.entries) {
      final resolvedValue = switch (value) {
        String() => value,
        int() => value.toString(),
        double() => value.toString(),
        bool() => value.toString(),
        null => '',
        _ => null,
      };

      if (resolvedValue == null) {
        continue;
      }

      result['$key'] = resolvedValue;
    }
  }

  return result;
}
