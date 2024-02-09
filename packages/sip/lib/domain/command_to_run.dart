class CommandToRun {
  const CommandToRun({
    required this.command,
    required this.workingDirectory,
    this.runConcurrently = false,
    String? label,
  }) : label = label ?? command;

  final String command;
  final String workingDirectory;
  final String label;
  final bool runConcurrently;
}
