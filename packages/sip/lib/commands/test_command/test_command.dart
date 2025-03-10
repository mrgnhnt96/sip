// ignore_for_file: cascade_invocations

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart' hide ExitCode;
import 'package:sip_cli/commands/test_clean_command.dart';
import 'package:sip_cli/commands/test_run_command.dart';
import 'package:sip_cli/commands/test_watch_command.dart';
import 'package:sip_cli/domain/bindings.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';
import 'package:sip_cli/domain/pubspec_yaml.dart';
import 'package:sip_cli/domain/run_many_scripts.dart';
import 'package:sip_cli/domain/run_one_script.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_cli/utils/key_press_listener.dart';

class TestCommand extends Command<ExitCode> {
  TestCommand({
    required PubspecYaml pubspecYaml,
    required FileSystem fs,
    required Logger logger,
    required Bindings bindings,
    required PubspecLock pubspecLock,
    required FindFile findFile,
    required KeyPressListener keyPressListener,
    required ScriptsYaml scriptsYaml,
    required RunManyScripts runManyScripts,
    required RunOneScript runOneScript,
  }) {
    addSubcommand(
      TestRunCommand(
        bindings: bindings,
        findFile: findFile,
        fs: fs,
        logger: logger,
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
        scriptsYaml: scriptsYaml,
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
      ),
    );

    addSubcommand(
      TestCleanCommand(
        bindings: bindings,
        findFile: findFile,
        fs: fs,
        logger: logger,
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
        scriptsYaml: scriptsYaml,
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
      ),
    );

    addSubcommand(
      TestWatchCommand(
        bindings: bindings,
        findFile: findFile,
        fs: fs,
        logger: logger,
        pubspecLock: pubspecLock,
        pubspecYaml: pubspecYaml,
        keyPressListener: keyPressListener,
        scriptsYaml: scriptsYaml,
        runManyScripts: runManyScripts,
        runOneScript: runOneScript,
      ),
    );
  }

  @override
  String get description => 'Run flutter or dart tests';

  @override
  String get name => 'test';
}
