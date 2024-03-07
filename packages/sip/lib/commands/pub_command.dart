import 'package:args/command_runner.dart';
import 'package:sip_cli/commands/pub_get_command.dart';
import 'package:sip_cli/commands/pub_upgrade_command.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

/// The `pub` command.
class PubCommand extends Command<ExitCode> {
  PubCommand({
    required PubspecLock pubspecLock,
    required PubspecYaml pubspecYaml,
  }) {
    addSubcommand(
      PubGetCommand(
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
      ),
    );
    addSubcommand(
      PubUpgradeCommand(
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
      ),
    );
  }

  @override
  String get description => 'Modify dependencies in pubspec.yaml file.';

  @override
  String get name => 'pub';
}
