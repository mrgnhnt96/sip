import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/domain/command_result.dart';
import 'package:sip_cli/domain/command_to_run.dart';
import 'package:sip_cli/utils/exit_code.dart';

extension ListExitCodeX on List<CommandResult> {
  void printErrors(Iterable<CommandToRun> commands_, Logger logger) {
    final commands = commands_.toList();

    for (var i = 0; i < length; i++) {
      this[i]._printError(
        index: i,
        label: commands[i].keys.join(' '),
        logger: logger,
      );
    }
  }

  ExitCode exitCode(Logger logger) {
    final mapped = asMap().map((key, value) => MapEntry(value.exitCode, value))
      ..remove(ExitCode.success.code);

    if (mapped.isEmpty) {
      logger.detail('Many exit codes: $this, returning success');
      return ExitCode.success;
    }

    if (mapped.length == 1) {
      logger.detail('Many exit codes: $this, returning ${mapped.values.first}');
      return mapped.values.first.exitCodeReason;
    }

    logger.detail('Many exit codes: $this, returning unavailable');
    return ExitCode.unavailable;
  }
}

extension CommandResultX on CommandResult {
  void _printError({
    required int? index,
    required String label,
    required Logger logger,
  }) {
    if (exitCodeReason == ExitCode.success) return;

    if (output.trim().isNotEmpty) {
      logger
        ..write(darkGray.wrap('--- OUTPUT ---\n'))
        ..write(output)
        ..write('---\n\n');
    }

    if (error.trim().isNotEmpty) {
      logger
        ..write(darkGray.wrap('--- ERROR ---\n'))
        ..write(error)
        ..write('---\n\n');
    }

    logger.write(
      '${red.wrap('✗')}  Script ${lightCyan.wrap('sip run $label')} '
      'failed with exit code ${lightRed.wrap(exitCodeReason.toString())}\n',
    );
  }

  void printError(CommandToRun command, Logger logger) {
    if (exitCodeReason == ExitCode.success) return;

    _printError(
      index: null,
      label: command.keys.join(' '),
      logger: logger,
    );
  }
}
