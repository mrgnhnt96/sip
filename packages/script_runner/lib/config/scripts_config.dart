import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sip_script_runner/config/script.dart';

part 'scripts_config.g.dart';

@JsonSerializable(createFactory: false)
class ScriptsConfig extends Equatable {
  const ScriptsConfig({
    required this.scripts,
  });

  factory ScriptsConfig.fromJson(Map json) {
    final scripts = <String, Script>{};
    for (final entry in json.entries) {
      scripts[entry.key] = Script.fromJson(entry.value);
    }

    return ScriptsConfig(scripts: scripts);
  }

  @JsonKey(defaultValue: {})
  final Map<String, Script> scripts;

  Map<String, dynamic> toJson() => _$ScriptsConfigToJson(this);

  @override
  List<Object?> get props => _$props;
}
