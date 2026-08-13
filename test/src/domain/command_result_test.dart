import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/domain/command_result.dart';
import 'package:test/test.dart';

void main() {
  group(CommandResult, () {
    CommandResult result(int exitCode) =>
        CommandResult(exitCode: exitCode, output: '', error: '');

    test('maps a known code to its ExitCode', () {
      expect(result(0).exitCodeReason, ExitCode.success);
      expect(result(65).exitCodeReason, ExitCode.data);
      expect(result(70).exitCodeReason, ExitCode.software);
      expect(result(78).exitCodeReason, ExitCode.config);
    });

    test('falls back to software, not usage, for an unmapped code', () {
      // `usage` (64) claims the CLI was invoked wrongly. 1 and 127 are the
      // ordinary ways a shell command reports its own failure.
      for (final code in [1, 2, 127]) {
        expect(
          result(code).exitCodeReason,
          ExitCode.software,
          reason: 'exit $code should read as a failure, not a usage error',
        );
        expect(result(code).exitCodeReason, isNot(ExitCode.usage));
      }
    });
  });
}
