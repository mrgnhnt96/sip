import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class RunManyScripts {
  const RunManyScripts({
    required this.commands,
    required this.bindings,
  });

  final Bindings bindings;
  final Iterable<CommandToRun> commands;

  Future<List<ExitCode>> run() async {
    final result = await _run(commands);

    return result;
  }

  Future<List<ExitCode>> _run(Iterable<CommandToRun> commands) async {
    getIt<SipConsole>().emptyLine();

    final exitCodes = await Future.wait(commands.map(
      (e) => RunOneScript(
        command: e,
        bindings: bindings,
        showOutput: false,
      ).run(),
    ));

    return exitCodes;
  }
}
