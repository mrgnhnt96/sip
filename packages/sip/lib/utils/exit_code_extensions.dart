import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

extension ListExitCodeX on List<ExitCode> {
  void printErrors(Iterable<CommandToRun> commands_, Logger logger) {
    final commands = commands_.toList();

    for (var i = 0; i < length; i++) {
      this[i]._printError(
        index: i,
        label: commands[i].label,
        logger: logger,
      );
    }
  }

  ExitCode exitCode(Logger logger) {
    final mapped = asMap().map((key, value) => MapEntry(value.code, value))
      ..remove(ExitCode.success.code);

    if (mapped.isEmpty) {
      logger.detail('Many exit codes: $this, returning success');
      return ExitCode.success;
    }

    if (mapped.length == 1) {
      logger.detail('Many exit codes: $this, returning ${mapped.values.first}');
      return mapped.values.first;
    }

    logger.detail('Many exit codes: $this, returning unavailable');
    return ExitCode.unavailable;
  }
}

extension ExitCodeX on ExitCode {
  void _printError({
    required int? index,
    required String label,
    required Logger logger,
  }) {
    if (this == ExitCode.success) return;

    logger.write(
      '${red.wrap('✗')}  Script ${lightCyan.wrap(label)} '
      'failed with exit code ${lightRed.wrap(toString())}\n',
    );
  }

  void printError(CommandToRun command, Logger logger) {
    if (this == ExitCode.success) return;

    _printError(
      index: null,
      label: command.label,
      logger: logger,
    );
  }
}
