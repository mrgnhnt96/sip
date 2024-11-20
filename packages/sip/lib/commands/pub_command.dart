import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/commands/pub_constrain_command.dart';
import 'package:sip_cli/commands/pub_deps_command.dart';
import 'package:sip_cli/commands/pub_downgrade_command.dart';
import 'package:sip_cli/commands/pub_get_command.dart';
import 'package:sip_cli/commands/pub_upgrade_command.dart';
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/constrain_pubspec_versions.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/utils/exit_code.dart';

/// The `pub` command.
class PubCommand extends Command<ExitCode> {
  PubCommand({
    required PubspecLock pubspecLock,
    required PubspecYaml pubspecYaml,
    required FindFile findFile,
    required FileSystem fs,
    required Logger logger,
    required Bindings bindings,
  }) {
    addSubcommand(
      PubGetCommand(
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
        findFile: findFile,
        fs: fs,
        logger: logger,
        bindings: bindings,
      ),
    );
    addSubcommand(
      PubUpgradeCommand(
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
        findFile: findFile,
        fs: fs,
        logger: logger,
        bindings: bindings,
      ),
    );
    addSubcommand(
      PubDepsCommand(
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
        findFile: findFile,
        fs: fs,
        logger: logger,
        bindings: bindings,
      ),
    );
    addSubcommand(
      PubDowngradeCommand(
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
        findFile: findFile,
        fs: fs,
        logger: logger,
        bindings: bindings,
      ),
    );
    addSubcommand(
      PubConstrainCommand(
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
        findFile: findFile,
        fs: fs,
        logger: logger,
        bindings: bindings,
        constrainPubspecVersions: ConstrainPubspecVersions(
          fs: fs,
          logger: logger,
        ),
      ),
    );
  }

  @override
  String get description => 'Modify dependencies in pubspec.yaml file.';

  @override
  String get name => 'pub';
}
