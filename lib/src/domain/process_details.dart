class ProcessDetails {
  const ProcessDetails({
    required this.stdout,
    required this.stderr,
    required this.pid,
    required this.exitCode,
    required this.kill,
  });

  final Stream<List<int>> stdout;
  final Stream<List<int>> stderr;
  final int pid;
  final Future<int> exitCode;
  final void Function() kill;
}
