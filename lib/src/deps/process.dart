import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/domain/process_details.dart';

typedef Process =
    Future<ProcessDetails> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment,
      bool runInShell,
      io.ProcessStartMode mode,
    });

final processProvider = create<Process>(() {
  return (
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    io.ProcessStartMode mode = io.ProcessStartMode.normal,
  }) async {
    final process = await io.Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory ?? fs.currentDirectory.path,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );

    final stdoutController = StreamController<List<int>>.broadcast();
    final stderrController = StreamController<List<int>>.broadcast();

    StreamSubscription<List<int>>? stdoutSubscription;
    try {
      stdoutSubscription = process.stdout.listen(stdoutController.add);
    } catch (_) {}

    StreamSubscription<List<int>>? stderrSubscription;
    try {
      stderrSubscription = process.stderr.listen(stderrController.add);
    } catch (_) {}

    Stream<String> stdout() async* {
      try {
        yield* stdoutController.stream.transform(utf8.decoder);
      } catch (_) {
        // ignore
      }
    }

    Stream<String> stderr() async* {
      try {
        yield* stderrController.stream.transform(utf8.decoder);
      } catch (_) {
        // ignore
      }
    }

    return ProcessDetails(
      stdout: stdout(),
      stderr: stderr(),
      pid: process.pid,
      exitCode: process.exitCode,
      kill: () {
        process.kill(io.ProcessSignal.sigkill);
        stdoutSubscription?.cancel();
        stderrSubscription?.cancel();
        stdoutController.close();
        stderrController.close();
      },
    );
  };
});

Process get process => read(processProvider);
