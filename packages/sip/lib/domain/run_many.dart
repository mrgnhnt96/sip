import 'dart:isolate';
import 'dart:math';

import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class RunMany {
  const RunMany({
    required this.commands,
    this.bindings = const BindingsImpl(),
    this.maxConcurrent,
  });

  final Bindings bindings;
  final List<CommandToRun> commands;
  final int? maxConcurrent;

  Future<ExitCode> run() async {
    final groups = <List<CommandToRun>>[];

    final maxConcurrent = this.maxConcurrent;
    if (maxConcurrent != null) {
      while (commands.isNotEmpty) {
        groups.add(commands.take(maxConcurrent).toList());
        commands.removeRange(0, min(commands.length, maxConcurrent));
      }
    } else {
      groups.add(commands);
    }

    for (final group in groups) {
      final result = await _run(group);

      if (result != ExitCode.success) {
        return result;
      }
    }

    return ExitCode.success;
  }

  Future<ExitCode> _run(List<CommandToRun> commands) async {
    for (final command in commands) {
      getIt<SipConsole>().l(command.label ?? command.command);
    }

    // lets try to change this to a stream controller instead of futures, this way we can
    // run the scripts as they finish instead of waiting for all of them to finish
    final scriptsToRun = <Future<int>>[];
    for (var i = 0; i < commands.length; i++) {
      final command = commands[i];

      final logger = getIt<SipConsole>();

      final finish = () {
        logger.l(
          '${command.label ?? command.command} finished',
        );
      };

      scriptsToRun.add(
        Isolate.run(() async {
          var cmd = '${command.command}';
          if (command.directory != null) {
            cmd = 'cd ${command.directory} && $cmd';
          }

          final result = await bindings.runScript(cmd, showOutput: false);

          finish();

          return result;
        }),
      );
    }

    final results = await Future.wait(scriptsToRun);

    if (results.any((code) => code != ExitCode.success.code)) {
      getIt<SipConsole>().e('One or more scripts failed');

      return ExitCode.ioError;
    }

    return ExitCode.success;
  }
}

class CommandToRun {
  const CommandToRun({
    required this.command,
    this.directory,
    this.label,
  });

  final String command;
  final String? directory;
  final String? label;
}
