class ProcessDetails {
  const ProcessDetails({
    required this.stdout,
    required this.stderr,
    required this.pid,
    required this.exitCode,
    required this.kill,
  });

  final Stream<String> stdout;
  final Stream<String> stderr;
  final int pid;
  final Future<int> exitCode;
  final void Function() kill;
}
