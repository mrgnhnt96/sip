import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:sip_cli/src/domain/command_to_run.dart';
import 'package:sip_cli/src/utils/exit_code.dart';

extension ListExitCodeX on List<CommandResult> {
  void printErrors(Iterable<CommandToRun> commands_, Logger logger) {
    final commands = commands_.toList();

    for (var i = 0; i < length; i++) {
      this[i]._printError(
        index: i,
        label: commands[i].keys.join(' '),
        workingDirectory: commands[i].workingDirectory,
        logger: logger,
      );
    }
  }

  ExitCode exitCode(Logger logger) {
    final mapped = asMap().map((key, value) => MapEntry(value.exitCode, value))
      ..remove(ExitCode.success.code);

    if (mapped.isEmpty) {
      logger.detail('Many exit codes: returning success');
      return ExitCode.success;
    }

    if (mapped.length == 1) {
      logger.detail(
        'Many exit codes: ${join('\n')}, returning ${mapped.values.first}',
      );
      return mapped.values.first.exitCodeReason;
    }

    logger.detail('Many exit codes: ${join('\n')}, returning unavailable');
    return ExitCode.unavailable;
  }

  bool get hasFailures =>
      any((element) => element.exitCodeReason != ExitCode.success);
}

extension CommandResultX on CommandResult {
  void _printError({
    required int? index,
    required String label,
    required String workingDirectory,
    required Logger logger,
  }) {
    if (exitCodeReason == ExitCode.success) return;

    if (output.trim().isNotEmpty) {
      logger
        ..write(darkGray.wrap('\n--- OUTPUT ---\n'))
        ..write(output)
        ..write(darkGray.wrap('--- OUTPUT ---\n'));
    }

    if (error.trim().isNotEmpty) {
      logger
        ..write(darkGray.wrap('\n--- ERROR ---\n'))
        ..write(error)
        ..write(darkGray.wrap('--- ERROR ---\n'));
    }

    logger.write(
      [
        '\n${red.wrap('✗')}  Script ${lightCyan.wrap('sip run $label')} ',
        '${darkGray.wrap('Directory: $workingDirectory')}',
        if (index != null) '${darkGray.wrap('Command Index: $index')}',
        'failed with exit code ${lightRed.wrap(exitCodeReason.toString())}\n',
      ].join('\n'),
    );
  }

  void printError(CommandToRun command, Logger logger) {
    if (exitCodeReason == ExitCode.success) return;

    _printError(
      index: null,
      label: command.keys.join(' '),
      workingDirectory: command.workingDirectory,
      logger: logger,
    );
  }
}
