import 'package:args/command_runner.dart';
import 'package:sip_cli/src/commands/pub_constrain_command.dart';
import 'package:sip_cli/src/commands/pub_deps_command.dart';
import 'package:sip_cli/src/commands/pub_downgrade_command.dart';
import 'package:sip_cli/src/commands/pub_get_command.dart';
import 'package:sip_cli/src/commands/pub_upgrade_command.dart';
import 'package:sip_cli/src/utils/exit_code.dart';

/// The `pub` command.
class PubCommand extends Command<ExitCode> {
  PubCommand() {
    addSubcommand(PubGetCommand());
    addSubcommand(PubUpgradeCommand());
    addSubcommand(PubDepsCommand());
    addSubcommand(PubDowngradeCommand());
    addSubcommand(PubConstrainCommand());
  }

  @override
  String get description => 'Modify dependencies in pubspec.yaml file.';

  @override
  String get name => 'pub';
}
