class CommandToRun {
  const CommandToRun({
    required this.command,
    required this.workingDirectory,
    this.label,
  });

  final String command;
  final String workingDirectory;
  final String? label;
}
