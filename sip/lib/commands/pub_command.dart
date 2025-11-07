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
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
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
    required ScriptsYaml scriptsYaml,
    required RunManyScripts runManyScripts,
    required RunOneScript runOneScript,
  }) {
    addSubcommand(
      PubGetCommand(
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
        findFile: findFile,
        fs: fs,
        logger: logger,
        bindings: bindings,
        scriptsYaml: scriptsYaml,
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
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
        scriptsYaml: scriptsYaml,
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
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
        scriptsYaml: scriptsYaml,
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
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
        scriptsYaml: scriptsYaml,
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
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
        scriptsYaml: scriptsYaml,
      ),
    );
  }

  @override
  String get description => 'Modify dependencies in pubspec.yaml file.';

  @override
  String get name => 'pub';
}
