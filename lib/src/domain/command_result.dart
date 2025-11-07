import 'package:json_annotation/json_annotation.dart';
import 'package:sip_cli/src/utils/exit_code.dart';

part 'command_result.g.dart';

@JsonSerializable()
class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.output,
    required this.error,
  });
  const CommandResult.unknown() : exitCode = 1, output = '', error = '';

  factory CommandResult.fromJson(Map<dynamic, dynamic> json) =>
      _$CommandResultFromJson(json);

  final int exitCode;
  final String output;
  final String error;

  Map<String, dynamic> toJson() => _$CommandResultToJson(this);

  ExitCode get exitCodeReason {
    final codes = {
      ExitCode.success.code: ExitCode.success,
      ExitCode.usage.code: ExitCode.usage,
      ExitCode.data.code: ExitCode.data,
      ExitCode.noInput.code: ExitCode.noInput,
      ExitCode.noUser.code: ExitCode.noUser,
      ExitCode.noHost.code: ExitCode.noHost,
      ExitCode.unavailable.code: ExitCode.unavailable,
      ExitCode.software.code: ExitCode.software,
      ExitCode.osError.code: ExitCode.osError,
      ExitCode.osFile.code: ExitCode.osFile,
      ExitCode.cantCreate.code: ExitCode.cantCreate,
      ExitCode.ioError.code: ExitCode.ioError,
      ExitCode.tempFail.code: ExitCode.tempFail,
      ExitCode.noPerm.code: ExitCode.noPerm,
      ExitCode.config.code: ExitCode.config,
    };

    return codes[exitCode] ?? ExitCode.unknown(exitCode);
  }

  @override
  String toString() {
    final buffer = StringBuffer()..write('CommandResult($exitCode');
    if (output.trim() case final output when output.isNotEmpty) {
      buffer.write(', output: $output');
    }
    if (error.trim() case final error when error.isNotEmpty) {
      buffer.write(', error: $error');
    }
    buffer.write(')');
    return buffer.toString();
  }
}
