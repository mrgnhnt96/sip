import 'package:sip_script_runner/domain/domain.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_console/domain/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';

extension ListExitCodeX on List<ExitCode> {
  void printErrors(Iterable<CommandToRun> _commands) {
    final commands = _commands.toList();

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
      getIt<SipConsole>().v('Many exit codes: $this, returning success');
      return ExitCode.success;
    }

    if (mapped.length == 1) {
      getIt<SipConsole>()
          .v('Many exit codes: $this, returning ${mapped.values.first}');
      return mapped.values.first;
    }

    getIt<SipConsole>().v('Many exit codes: $this, returning unavailable');
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
      'failed with exit code ${lightRed.wrap(this.toString())}',
    );
  }

  void printError(CommandToRun command) {
    if (this == ExitCode.success) return;

    _printError(index: null, label: command.label);
  }
}
