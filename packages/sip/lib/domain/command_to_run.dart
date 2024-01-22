class CommandToRun {
  const CommandToRun({
    required this.command,
    required this.workingDirectory,
    String? label,
  }) : label = label ?? command;

  final String command;
  final String workingDirectory;
  final String label;
}
