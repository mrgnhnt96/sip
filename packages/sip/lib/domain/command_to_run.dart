import 'package:equatable/equatable.dart';

part 'command_to_run.g.dart';

class CommandToRun extends Equatable {
  const CommandToRun({
    required this.command,
    required this.workingDirectory,
    required this.keys,
    this.runConcurrently = false,
    this.envFile = const [],
    String? label,
  }) : label = label ?? command;

  final String command;
  final String workingDirectory;
  final String label;
  final List<String> envFile;
  final bool runConcurrently;
  final List<String> keys;

  @override
  List<Object?> get props => _$props;
}
