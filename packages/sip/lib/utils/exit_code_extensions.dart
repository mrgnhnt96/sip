import 'package:sip/domain/command_to_run.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_console/domain/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';

extension ListExitCodeX on List<ExitCode> {
  void printErrors(List<CommandToRun> commands) {
    for (var i = 0; i < length; i++) {
      this[i]._printError(
        index: i,
        label: commands[i].label,
      );
    }
  }

  ExitCode get exitCode {
    final mapped = asMap().map((key, value) => MapEntry(value.code, value));

    mapped.remove(ExitCode.success.code);

    if (mapped.isEmpty) {
      return ExitCode.success;
    }

    if (mapped.length == 1) {
      return mapped.values.first;
    }

    return ExitCode.unavailable;
  }
}

extension ExitCodeX on ExitCode {
  void _printError({
    required int? index,
    required String label,
  }) {
    if (this == ExitCode.success) return;

    final indexString = index == null ? '' : '(${index + 1}) ';
    getIt<SipConsole>().e(
      'Script $indexString${lightCyan.wrap(label)} '
      'failed with exit code $this',
    );
  }

  void printError(CommandToRun command) {
    if (this == ExitCode.success) return;

    _printError(index: null, label: command.label);
  }
}
