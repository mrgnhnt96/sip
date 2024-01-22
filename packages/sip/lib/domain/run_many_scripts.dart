import 'package:sip/domain/command_to_run.dart';
import 'package:sip/domain/run_one_script.dart';
import 'package:sip/domain/run_script.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class RunManyScripts implements RunScript {
  const RunManyScripts({
    required this.commands,
    required this.bindings,
  });

  final Bindings bindings;
  final List<CommandToRun> commands;

  Future<ExitCode> run() async {
    final result = await _run(commands);

    return result;
  }

  Future<ExitCode> _run(List<CommandToRun> commands) async {
    for (final command in commands) {
      getIt<SipConsole>().l(command.label ?? command.command);
    }

    final results = await Future.wait(commands.map(
      (e) => RunOneScript(command: e, bindings: bindings).run(),
    ));

    if (results.any((code) => code != ExitCode.success)) {
      getIt<SipConsole>().e('One or more scripts failed');

      return ExitCode.ioError;
    }

    return ExitCode.success;
  }
}
