// ignore_for_file: cascade_invocations

import 'package:args/command_runner.dart';
import 'package:sip_cli/src/commands/test_clean_command.dart';
import 'package:sip_cli/src/commands/test_run_command.dart';
import 'package:sip_cli/src/commands/test_watch_command.dart';
import 'package:sip_cli/src/utils/exit_code.dart';

class TestCommand extends Command<ExitCode> {
  TestCommand() {
    addSubcommand(TestRunCommand());
    addSubcommand(TestCleanCommand());
    addSubcommand(TestWatchCommand());
  }

  @override
  String get description => 'Run flutter or dart tests';

  @override
  String get name => 'test';
}
