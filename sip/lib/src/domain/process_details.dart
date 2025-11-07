class ProcessDetails {
  const ProcessDetails({
    required this.stdout,
    required this.stderr,
    required this.pid,
    required this.exitCode,
  });

  final Stream<List<int>> stdout;
  final Stream<List<int>> stderr;
  final int pid;
  final Future<int> exitCode;
}
