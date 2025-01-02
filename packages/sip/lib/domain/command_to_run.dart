import 'package:equatable/equatable.dart';
import 'package:sip_cli/domain/env_config.dart';
import 'package:sip_cli/domain/filter_type.dart';

part 'command_to_run.g.dart';

class CommandToRun extends Equatable {
  const CommandToRun({
    required this.command,
    required this.workingDirectory,
    required this.keys,
    this.envConfig,
    this.runConcurrently = false,
    this.filterOutput,
    String? label,
  }) : label = label ?? command;

  final String command;
  final String workingDirectory;
  final String label;
  final bool runConcurrently;
  final Iterable<String> keys;
  final EnvConfig? envConfig;
  final FilterType? filterOutput;

  @override
  List<Object?> get props => _$props;
}
