import 'package:sip/domain/command_to_run.dart';
import 'package:sip/domain/run_one_script.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class RunManyScripts {
  const RunManyScripts({
    required this.commands,
    required this.bindings,
  });

  final Bindings bindings;
  final List<CommandToRun> commands;

  Future<List<ExitCode>> run() async {
    final result = await _run(commands);

    return result;
  }

  Future<List<ExitCode>> _run(List<CommandToRun> commands) async {
    getIt<SipConsole>().emptyLine();

    final exitCodes = await Future.wait(commands.map(
      (e) => RunOneScript(command: e, bindings: bindings).run(),
    ));

    for (var i = 0; i < exitCodes.length; i++) {
      final exitCode = exitCodes[i];

      if (exitCode != ExitCode.success) {
        getIt<SipConsole>().e(
          'Script (${i + 1}) ${lightCyan.wrap('${commands[i].label}')} failed '
          'with exit code ${lightRed.wrap(exitCode.toString())}',
        );
      }
    }

    getIt<SipConsole>().emptyLine();

    return exitCodes;
  }
}