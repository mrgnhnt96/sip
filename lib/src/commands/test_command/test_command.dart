// ignore_for_file: cascade_invocations

import 'package:sip_cli/src/commands/test_clean_command.dart';
import 'package:sip_cli/src/commands/test_run_command.dart';
import 'package:sip_cli/src/commands/test_watch_command.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/utils/exit_code.dart';

const _usage = '''
Usage: sip test <command>

Run flutter or dart tests

Commands:
  [run]       Run tests
  clean       Clean tests
  watch       Watch tests
''';

class TestCommand {
  const TestCommand();

  Future<ExitCode> run(List<String> path) async {
    if (args.get<bool>('help', defaultValue: false) && path.isEmpty) {
      logger.write(_usage);
      return ExitCode.success;
    }

    switch (path) {
      case ['clean']:
        return await TestCleanCommand().run();
      case ['watch', ...final paths]:
        return await TestWatchCommand().run(paths);
      case ['run', ...final paths] || [...final paths]:
        return await const TestRunCommand().run(paths);
    }
  }
}
