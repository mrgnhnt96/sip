import 'package:equatable/equatable.dart';
import 'package:sip_cli/domain/env_config.dart';

part 'command_to_run.g.dart';

class CommandToRun extends Equatable {
  const CommandToRun({
    required this.command,
    required this.workingDirectory,
    required this.keys,
    this.runConcurrently = false,
    this.envFile = const EnvConfig.empty(),
    String? label,
  }) : label = label ?? command;

  final String command;
  final String workingDirectory;
  final String label;
  final EnvConfig envFile;
  final bool runConcurrently;
  final List<String> keys;

  @override
  List<Object?> get props => _$props;
}
