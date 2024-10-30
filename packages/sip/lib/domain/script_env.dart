import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sip_cli/utils/try_read_list_or_string.dart';

part 'script_env.g.dart';

@JsonSerializable()
class ScriptEnv extends Equatable {
  const ScriptEnv({
    this.files = const [],
    this.commands = const [],
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
