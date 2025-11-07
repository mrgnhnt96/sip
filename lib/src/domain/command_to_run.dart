import 'package:equatable/equatable.dart';
import 'package:sip_cli/src/domain/env_config.dart';
import 'package:sip_cli/src/domain/filter_type.dart';

part 'command_to_run.g.dart';

class CommandToRun extends Equatable {
  const CommandToRun({
    required this.command,
    required this.workingDirectory,
    required this.keys,
    this.bail = false,
    this.envConfig,
    this.runConcurrently = false,
    this.filterOutput,
    this.needsRunBeforeNext = false,
    String? label,
  }) : label = label ?? command;

  final String command;
  final String workingDirectory;
  final String label;
  final bool runConcurrently;
  final Iterable<String> keys;
  final EnvConfig? envConfig;
  final FilterType? filterOutput;
  final bool bail;

  /// Whether to run the previous command first.
  ///
  /// This is useful to "break" up the commands into smaller concurrent groups
  ///
  /// This does not apply if [runConcurrently] is false
  final bool needsRunBeforeNext;

  @override
  List<Object?> get props => _$props;
}
