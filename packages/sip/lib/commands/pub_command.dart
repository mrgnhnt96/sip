import 'package:args/command_runner.dart';
import 'package:sip_cli/commands/pub_get_command.dart';
import 'package:sip_cli/commands/pub_upgrade_command.dart';
import 'package:sip_cli/utils/exit_code.dart';

/// The `pub` command.
class PubCommand extends Command<ExitCode> {
  PubCommand() {
    addSubcommand(PubGetCommand());
    addSubcommand(PubUpgradeCommand());
  }

  @override
  String get description => 'Modify dependencies in pubspec.yaml file.';

  @override
  String get name => 'pub';
}
