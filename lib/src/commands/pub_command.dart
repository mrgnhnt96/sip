import 'package:sip_cli/src/commands/pub_constrain_command.dart';
import 'package:sip_cli/src/commands/pub_deps_command.dart';
import 'package:sip_cli/src/commands/pub_downgrade_command.dart';
import 'package:sip_cli/src/commands/pub_get_command.dart';
import 'package:sip_cli/src/commands/pub_upgrade_command.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';
import 'package:sip_cli/src/utils/exit_code.dart';

const _usage = '''
Usage: sip pub <command>

Modify dependencies in pubspec.yaml file.

Commands:
  get       Get dependencies
  upgrade   Upgrade dependencies
  deps      Print package dependencies
  downgrade Downgrade dependencies
  constrain Constrain dependencies
''';

/// The `pub` command.
class PubCommand {
  const PubCommand();

  Future<ExitCode> run(List<String> path) async {
    if (args.get<bool>('help', defaultValue: false) && path.isEmpty) {
      logger.write(_usage);
      return ExitCode.success;
    }

    switch (path) {
      case ['get']:
        return await const PubGetCommand().run();
      case ['upgrade' || 'up' || 'update']:
        return await const PubUpgradeCommand().run();
      case ['deps']:
        return await const PubDepsCommand().run();
      case ['downgrade']:
        return await const PubDowngradeCommand().run();
      case ['constrain']:
        return await const PubConstrainCommand().run();
      default:
        logger.write(_usage);

        return ExitCode.usage;
    }
  }
}
