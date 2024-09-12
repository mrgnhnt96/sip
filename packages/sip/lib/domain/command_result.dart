class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.output,
    required this.error,
  });

  final int exitCode;
  final String output;
  final String error;
}
